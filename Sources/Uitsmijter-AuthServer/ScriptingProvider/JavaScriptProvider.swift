import Foundation
import Logging
import Logger
import JXKit // Replacement for JavaScriptCore, works with webkitgtk-4.0

/// An actor that can execute plugins as providers for tasks that can be customized.
/// Plugins can be written in javascript-classes with a specific name and have to implement a protocol/interface
/// that fulfills the requirements that are described in the documentation.
///
/// Providers handle tasks that are unique to a project.
/// - See:
///     - UserLoginProvider: A class that fetches a service to validates a username and a password. Must implement
/// `canLogin` and `userProfile`
///     - UserValidateProvider: A class that validates a user. Must implement `isValid`
///
/// - Note: Converted to actor for thread-safe access to JavaScript context and results. Actor isolation provides
/// automatic serialization of access to shared mutable state, eliminating the need for manual DispatchQueue/DispatchGroup
/// synchronization. Per ACTOR.md recommendations.
///
actor JavaScriptProvider: JSFunctionsDelegate {
    /// The context for the provider plugins. Multiple scripts can be loaded into one context.
    ///
    /// - Important: Every requesting user should have its own context.
    ///
    private let ctx: JXContext

    /// Continuation for async/await coordination with JavaScript commit callback.
    /// This replaces the DispatchGroup pattern with proper Swift concurrency.
    ///
    private var commitContinuation: CheckedContinuation<[String?], Error>?

    /// The execution inside the javascript cannot be monitored from outside the script itself. To get track of the
    /// state of the javascript, it has to `commit` its final results back into the caller stack once.
    /// Actor isolation ensures thread-safe access to this property.
    ///
    private(set) var committedResults: [String?]? {
        didSet {
            if let committedResults {
                Log.debug(
                    "Got \(committedResults.count) results from javascript as committed result: \(committedResults)"
                )
            }
        }
    }

    /// The execution of the javascript provider plugins can fail. `JavaScriptError` describes different reasons why
    /// the script stopped its execution.
    ///
    /// - See:
    ///     - run
    ///     - exceptionHandler
    ///
    enum JavaScriptError: Error {
        case syntaxError(String?)
        case parserError(String)
        case propertyCast(String, class: String, into: any Sendable)
        case timeout
        case noResults
    }

    /// Function variable that is called when a javascript exception occurs
    /// Logs the exception to the error log
    ///
    /// - Note: Exception handler no longer needs DispatchGroup parameter as actor isolation
    /// handles synchronization automatically
    ///
    nonisolated let exceptionHandler: @Sendable (JXContext?, JXValue?) -> Void = { _, exception in
        if let exception {
            do {
                let jsonException = try exception.toJSON()
            } catch {
                Log.error("\(error.localizedDescription)")
            }

            let exceptionJSON: String = (try? exception.toJSON()) ?? ""
            Log.error(
                "\(exception.localizedDescription): "
                    + "\(exception.stringValue ?? "-") "
                    + "| \(exceptionJSON)"
            )
        }
    }

    /// Creates a new empty JavaScriptProvider with an isolated javascript context
    ///
    init() {
        // javascript context
        ctx = JXContext()
        ctx.exceptionHandler = exceptionHandler

        // Bind function implementation to the context
        // @see JSFunctions
        var functions = JSFunctions(bind: ctx, delegate: self)
        // convenience call to be swift likely (readability)
        functions.delegate = self
    }

    // MARK: - JSFunctionsDelegate

    /// Is called when `commit` is called from within the javascript context
    ///
    /// - Parameter data: Array of strings that are committed from within the javascript context
    ///
    /// - Note: Nonisolated method that can be called from JavaScript callbacks without awaiting.
    /// Uses Task to safely update actor-isolated state.
    ///
    nonisolated func valueDidCommitted(data: [String?]) {
        Task {
            await self.handleCommit(data: data)
        }
    }

    /// Actor-isolated helper to update committed results and resume continuation.
    ///
    private func handleCommit(data: [String?]) {
        // set result to actor-isolated variable
        committedResults = data

        // Resume the continuation if one is waiting
        if let continuation = commitContinuation {
            commitContinuation = nil
            continuation.resume(returning: data)
        }
    }

    // MARK: - Public functions to control the provider

    /// Load the given `script` into the context
    ///
    /// It's possible to load a bunch of multiple scripts into the context before executing specific predefined methods
    /// with `run(func:)`
    ///
    /// - SeeAlso: run
    ///
    /// - Parameter script: Plaintext script to load into the context
    /// - Throws: A JavaScriptError when the syntax is invalid
    ///
@discardableResult func loadProvider(script: String) throws -> String {
        // Maybe it slows down the process to check the script first, but will give proper information about syntax
        // errors which is important for the implementation developer
        if ctx.checkScriptSyntax(script) == false {
            let currentError = try? ctx.currentError?.toJSON()
            Log.error("Provider script failed loading. Error: \(currentError ?? "-")")
            throw try JavaScriptError.syntaxError(ctx.currentError?.toJSON())
        }

        // Drops the value, because `loadProvider` should only load classes by definition
        return try ctx.evaluateScript(script).toJSON()
    }

    /// Specification of the classes that can be run inside the provider script
    ///
    /// - See: start
    enum ScriptClassExecution: String, Sendable {
        case userLogin = "UserLoginProvider"
        case userValidate = "UserValidationProvider"
        case custom
    }

    /// Checks if a class exists in the provided scripts
    ///
    /// - Parameter classToRun: A ScriptClassExecution to check
    /// - Returns: true if the class exists
    func isClassExists(class classToRun: ScriptClassExecution) -> Bool {
        let result = ctx.evaluateScript("""
                                        typeof \(classToRun.rawValue) === 'function'
                                        """)
        return result.booleanValue
    }

    /// Async method to execute a specific function in the javascript context
    ///
    /// - Parameters:
    ///     - classToRun: A ScriptClassExecution to run
    ///     - args: Arguments to pass into init function
    /// - Returns: An array of result strings that are committed
    /// - Throws: A JavaScriptError when something unexpected happens
    ///
    /// - Note: Fully async implementation using Task and continuation for timeout handling.
    /// Replaces the DispatchGroup/queue pattern with proper Swift concurrency.
    ///
    @discardableResult
    func start(
        class classToRun: ScriptClassExecution,
        arguments args: JSInputParameterProtocol?
    ) async throws -> [String?] {
        // Reset state for this execution
        committedResults = nil
        commitContinuation = nil

        // Execute JavaScript and wait for commit with timeout
        // Use Task.withThrowingTaskGroup but move logic to separate method to avoid closure issues
        return try await raceExecutionWithTimeout(classToRun: classToRun, args: args)
    }

    /// Helper method to race script execution against timeout.
    ///
    private func raceExecutionWithTimeout(
        classToRun: ScriptClassExecution,
        args: JSInputParameterProtocol?
    ) async throws -> [String?] {
        try await withThrowingTaskGroup(of: [String?].self) { group in
            let timeout = UInt64(Constants.PROVIDER.SCRIPT_TIMEOUT) * 1_000_000_000

            // Task 1: Execute script
            // The warning about sending 'self' is a false positive here because:
            // 1. We're calling an async actor method which properly handles synchronization
            // 2. The task group waits for completion, ensuring no dangling references
            group.addTask { @Sendable [isolated = self, classToRun, args] in
                try await isolated.executeScriptAndWaitForCommit(classToRun: classToRun, args: args)
            }

            // Task 2: Timeout
            group.addTask { @Sendable in
                try await Task.sleep(nanoseconds: timeout)
                throw JavaScriptError.timeout
            }

            // Return the first result (either commit or timeout)
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }

            throw JavaScriptError.noResults
        }
    }

    /// Helper method to execute script and wait for commit.
    /// Separated to avoid closure isolation issues.
    ///
    private func executeScriptAndWaitForCommit(
        classToRun: ScriptClassExecution,
        args: JSInputParameterProtocol?
    ) async throws -> [String?] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String?], Error>) in
            // Set up the continuation for JavaScript commit callback
            self.setCommitContinuation(continuation)

            // Evaluate the script - this starts the JavaScript execution
            do {
                let result = try self.evaluateScript(
                    classToRun: classToRun,
                    args: args
                )

                // Log the omitted result
                if let stringValue = result.stringValue {
                    if stringValue != "undefined" {
                        Log.info("Provider script omitted result: \(stringValue)")
                    }
                }
                if result.isBoolean {
                    let boolValue = result.booleanValue
                    Log.info("Provider script omitted boolean result: \(boolValue)")
                }
            } catch {
                // If script evaluation fails, resume with error
                self.resumeWithError(error)
            }
        }
    }

    /// Helper method to set the commit continuation (actor-isolated)
    private func setCommitContinuation(_ continuation: CheckedContinuation<[String?], Error>) {
        commitContinuation = continuation
    }

    /// Helper method to evaluate JavaScript (actor-isolated)
    private func evaluateScript(
        classToRun: ScriptClassExecution,
        args: JSInputParameterProtocol?
    ) throws -> JXValue {
        try ctx.evaluateScript("""
            let r_\(classToRun.rawValue) =
                new \(classToRun.rawValue)(\(args?.toJSON() ?? ""));
            """)
    }

    /// Helper method to resume continuation with error (actor-isolated)
    private func resumeWithError(_ error: Error) {
        if let continuation = commitContinuation {
            commitContinuation = nil
            continuation.resume(throwing: JavaScriptError.parserError(error.localizedDescription))
        }
    }

    /// Returns the property value from an initialized class as a Double
    ///
    /// - Parameters:
    ///   - classToRun: There can be more than one class loaded in the current context.
    ///   - property: The property name of the initialized class
    /// - Returns: The number stores in `property`
    /// - Throws: When it can not get the property value as a Double
    ///
    func getValue(class classToRun: ScriptClassExecution, property: String) throws -> Double {
        let value = try ctx.eval(script: "r_\(classToRun.rawValue).\(property)")
        guard let numberValue = value.numberValue else {
            throw JavaScriptError.propertyCast(property, class: classToRun.rawValue, into: Double.self)
        }
        return numberValue
    }

    /// Returns the property value from an initialized class as a Boolean
    ///
    /// - Parameters:
    ///   - classToRun: There can be more than one class loaded in the current context.
    ///   - property: The property name of the initialized class
    /// - Returns: The boolean stores in `property`
    /// - Throws: When it can not get the property value as a Bool
    ///
    func getValue(class classToRun: ScriptClassExecution, property: String) throws -> Bool {
        try ctx.eval(script: "r_\(classToRun.rawValue).\(property)").booleanValue
    }

    /// Returns the property value from an initialized class as a String
    ///
    /// - Parameters:
    ///   - classToRun: There can be more than one class loaded in the current context.
    ///   - property: The property name of the initialized class
    /// - Returns: The literal stores in `property`
    /// - Throws: When it can not get the property value as a String
    ///
    func getValue(class classToRun: ScriptClassExecution, property: String) throws -> String {
        let value = try ctx.eval(script: "r_\(classToRun.rawValue).\(property)")
        guard let stringValue = value.stringValue else {
            throw JavaScriptError.propertyCast(property, class: classToRun.rawValue, into: String.self)
        }
        return stringValue
    }

    func getObject<T: Decodable>(class classToRun: ScriptClassExecution, property: String) throws -> T {
        try ctx.eval(script: "r_\(classToRun.rawValue).\(property)").toDecodable(ofType: T.self)
    }
}
