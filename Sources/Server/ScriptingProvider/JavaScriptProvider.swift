import Foundation
import Logging
import JXKit // Replacement for JavaScriptCore, works with webkitgtk-4.0

/// A class that can execute plugins as a providers for tasks that can be customized.
/// Plugins can be written in javascript-classes with a specific name and have to be implement a protocol/interface
/// that fulfills the requirements that are described in the documentation.
///
/// Providers handles tasks that are unique to a project.
/// - See:
///     - UserLoginProvider: A class that fetches a service to validates a username and a password. Must implement
/// `canLogin` and `userProfile`
///     - UserValidateProvider: A class that validates a user. Must implement `isValid`
///
class JavaScriptProvider: JSFunctionsDelegate {
    /// The context for the provider plugins. Multiple scripts can be load into one context.
    ///
    /// - Important: very requesting user should have its own context.
    ///
    private let ctx: JXContext

    /// We are dealing with a asynchronous tasks that can't be synced between swift and javascript. This DispatchGroup
    /// is responsible to track script executions and waits for a `commit` from within the javascript to carry on with
    /// the execution.
    /// - See: committedResults
    ///
    private let group = DispatchGroup()
    private let queue = DispatchQueue(label: "js_evaluate", qos: .default, attributes: .concurrent)

    /// The execution inside the javascript can not be monitored from outside the script itself. To get track of the
    /// state of the javascript, it has to `commit` its final results back into the caller stack once. A `DispatchGroup`
    /// waits for the committed value and continue to run after the commit only.
    ///
    /// - See: group
    ///
    public private(set) var committedResults: [String?]? {
        didSet {
            if let committedResults {
                Log.info(
                        "Got \(committedResults.count) results from javascript as committed Result: \(committedResults)"
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
        case propertyCast(String, class: String, into: Any)
        case timeout
        case noResults
    }

    /// Function variable that is called when a javascript exception occurs
    /// Logs the exception to the error log
    ///
    let exceptionHandler = { (group: DispatchGroup) -> (JXContext?, JXValue?) -> Void in
        { _, exception in // swiftlint:disable:this opening_brace
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
                group.suspend()
            }
        }
    }

    /// Creates a new empty JavaScriptProvider with an isolated javascript context
    ///
    init() {
        // javascript context
        ctx = JXContext()
        ctx.exceptionHandler = exceptionHandler(group)

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
    func valueDidCommitted(data: [String?]) {
        // set result to class variable
        committedResults = data

        // leaf the DispatchGroup that is opened in `run`
        group.leave()
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
    enum ScriptClassExecution: String {
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
    /// - Returns: A array of result strings that are committed
    /// - Throws: A JavaScriptError when something unexpected happens
    ///
    @discardableResult
    func start(
            class classToRun: ScriptClassExecution,
            arguments args: JSInputParameterProtocol?
    ) async throws -> [String?] {
        return try await withCheckedThrowingContinuation { continuation in
            start(class: classToRun, arguments: args, completion: continuation.resume(with:))
        }

    }

    /// Callback method to execute a specific function in the javascript context
    ///
    /// - Attention: Consider to use the async method
    ///
    /// - Parameter
    ///     - classToRun: A ScriptClassExecution to run
    ///     - arguments: Arguments to pass into init function
    ///     - completion: Callback that is called when values are committed
    ///
    func start(
            class classToRun: ScriptClassExecution,
            arguments args: JSInputParameterProtocol?,
            completion: @escaping (Result<[String?], JavaScriptError>
            ) -> Void) {
        // enter the DispatchGroup to wait for a commit from within the javascript
        group.enter()
        do {
            // evaluate the script and get the result back. The result will be logged only, because the
            // script should run until the `commit` function is called.
            // swiftlint:disable trailing_whitespace
            let result = try ctx.evaluateScript("""
                                                let r_\(classToRun.rawValue) = 
                                                    new \(classToRun.rawValue)(\(args?.toJSON() ?? ""));
                                                """)
            // swiftlint:enable trailing_whitespace
            // Logs the omitted result
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
            // toJSON is the only function that can throw an exception. No need to switch/case between error causes
            completion(.failure(.parserError(error.localizedDescription)))
            return
        }
        // wait that the DispatchGroup did notified and take the committed result

        group.notify(queue: queue) { [self] in
            if let committedResults = committedResults {
                completion(.success(committedResults))
                return
            }
            // Fallthrough
            completion(.failure(.noResults))
            return
        }

        // Wait until timeout for the script to evaluate till commit is called
        _ = group.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(Constants.PROVIDER.SCRIPT_TIMEOUT))

        if committedResults == nil {
             completion(.failure(.timeout))
        }
        group.suspend()
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
