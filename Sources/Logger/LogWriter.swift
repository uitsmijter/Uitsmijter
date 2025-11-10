// swiftlint:disable file_length
import Foundation
import Logging
import FoundationExtensions
import Synchronization

/// A custom log handler implementation that provides formatted logging output and maintains a history of log messages.
///
/// `LogWriter` conforms to the `LogHandler` protocol from the Swift Logging API and provides enhanced functionality
/// for logging in the Uitsmijter application. It supports multiple output formats, maintains a circular buffer of
/// recent log messages, and provides filtering capabilities for common messages.
///
/// ## Features
///
/// - **Multiple Output Formats**: Supports both human-readable console output and machine-readable NDJSON format
/// - **Log History**: Maintains a circular buffer of the last 250 log messages for debugging and testing
/// - **Message Filtering**: Can skip predefined messages to reduce log noise
/// - **Audit Log Support**: Special handling for audit-type logs with distinct formatting
/// - **Thread Safety**: Uses NSLock for thread-safe property access, compatible with Swift 6 concurrency
///
/// ## Usage
///
/// ```swift
/// var logWriter = LogWriter(
///     metadata: [:],
///     logLevel: .info,
///     logFormat: .console
/// )
/// logWriter.log(
///     level: .info,
///     message: "Application started",
///     metadata: nil,
///     source: "Main",
///     file: #file,
///     function: #function,
///     line: #line
/// )
/// ```
///
/// ## Thread Safety
///
/// All mutable properties are protected by Swift 6's Mutex to ensure thread-safe access from any isolation domain.
/// Mutex provides cross-platform synchronization (macOS, Linux, Windows) with compile-time safety guarantees.
/// The class is marked as `@unchecked Sendable` because thread-safety is manually guaranteed through
/// the mutex. In practice, logging operations are typically serialized by the Swift Logging framework.
///
/// - Note: This handler is primarily designed for use with the Swift Logging API's `LoggingSystem.bootstrap()` method.
public final class LogWriter: @unchecked Sendable, LogHandler {

    /// Internal state protected by Swift 6 Mutex for thread-safe property access
    private struct State: ~Copyable {
        var metadata: Logger.Metadata
        var logLevel: Logger.Level
        var logFormat: LogFormat
        var lastLog: LogMessage?
    }

    private let state: Mutex<State>

    /// Messages that should be silently filtered and not logged.
    ///
    /// This array contains message strings that, while technically logged by various components,
    /// are common enough that they would clutter the logs without providing useful information.
    /// When a log message exactly matches any string in this array, it will be silently discarded.
    ///
    /// Currently filtered messages:
    /// - `"Request is missing JWT bearer header"`: Common when handling unauthenticated requests
    private let messagesSkipping: [String] = [
        // Info from JWT when no token is set, but this is a common scenario and should not float the log
        "Request is missing JWT bearer header"
    ]

    /// Creates a new `LogWriter` instance with the specified configuration.
    ///
    /// This initializer sets up the log writer with initial metadata, log level, and output format.
    /// It also configures the main JSON encoder to use ISO 8601 date encoding for consistent
    /// timestamp formatting in NDJSON output.
    ///
    /// - Parameters:
    ///   - metadata: Initial metadata to attach to all log messages from this handler.
    ///               This metadata will be merged with per-message metadata when logging.
    ///   - logLevel: The minimum log level for messages to be processed. Messages below
    ///               this level will be discarded by the logging framework.
    ///   - logFormat: The output format for log messages (console or NDJSON).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let writer = LogWriter(
    ///     metadata: ["service": "auth"],
    ///     logLevel: .debug,
    ///     logFormat: .ndjson
    /// )
    /// ```
    public init(metadata: Logger.Metadata, logLevel: Logger.Level, logFormat: LogFormat) {
        self.state = Mutex(State(
            metadata: metadata,
            logLevel: logLevel,
            logFormat: logFormat,
            lastLog: nil
        ))
        JSONEncoder.main.dateEncodingStrategy = .iso8601
    }

    /// A structured representation of a log message with all associated metadata and context.
    ///
    /// `LogMessage` captures all information about a single log event, including the message content,
    /// severity level, source location, and arbitrary metadata. It is designed to be encodable to JSON
    /// for NDJSON output format and for storage in the log buffer.
    ///
    /// ## Properties
    ///
    /// The struct includes both required message content and optional contextual information that
    /// may be omitted in release builds for performance and security reasons.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let logMsg = LogMessage(
    ///     level: "INFO",
    ///     message: "User authenticated",
    ///     metadata: ["user_id": "12345"],
    ///     source: "AuthModule",
    ///     file: "AuthController.swift",
    ///     function: "login()",
    ///     line: 42
    /// )
    /// ```
    ///
    /// - Note: File, function, and line information are typically omitted in release builds
    ///         to reduce log size and avoid exposing internal implementation details.
    /// - SeeAlso: ``logBuffer`` and ``lastLog`` for accessing logged messages
    public struct LogMessage: Encodable, Sendable {
        /// The severity level of the log message (e.g., "INFO", "ERROR", "AUDIT").
        ///
        /// This is stored as a string representation of the `Logger.Level` enum value,
        /// converted to uppercase. Special handling applies for audit logs where this
        /// value may be set to "AUDIT" regardless of the original log level.
        public var level: String

        /// The primary log message content.
        ///
        /// This is the main text describing the log event. It should be concise but
        /// descriptive enough to understand the event without additional context.
        public let message: String

        /// Additional structured data associated with this log message.
        ///
        /// Metadata provides key-value pairs of contextual information. Common examples include
        /// user IDs, request IDs, tenant information, or any domain-specific data relevant to
        /// the log event. Metadata from the `LogWriter` instance is merged with per-message metadata.
        ///
        /// - Note: The "type" metadata key is handled specially and removed after processing
        ///         (e.g., for audit log detection).
        public var metadata: Dictionary<String, String>?

        /// The source module or component that generated the log message.
        ///
        /// Typically represents the Swift module or logical subsystem where the log originated,
        /// helping to categorize and filter logs by component.
        public let source: String?

        /// The source file path where the log message was written.
        ///
        /// This provides precise location information for debugging. In release builds,
        /// this is typically set to `nil` to reduce log size.
        public let file: String?

        /// The function name where the log message was written.
        ///
        /// Helps identify the specific function context of the log. In release builds,
        /// this is typically set to `nil`.
        public let function: String?

        /// The line number where the log message was written.
        ///
        /// Provides exact source location for debugging. In release builds,
        /// this is typically set to `nil`.
        public let line: UInt?

        /// The timestamp when the log message was created.
        ///
        /// Automatically set to the current date and time when the `LogMessage` is instantiated.
        /// When encoded to JSON, this uses ISO 8601 format for consistency and parseability.
        public let date: Date = Date()
    }

    /// Defines the output format for log messages.
    ///
    /// `LogFormat` determines how log messages are formatted when written to standard output.
    /// Different formats are optimized for different use cases: human readability for development
    /// and machine parsing for production monitoring.
    ///
    /// ## Cases
    ///
    /// - **console**: Human-readable format with color-friendly spacing, suitable for terminal output
    ///   during development. Includes additional debug information when compiled in DEBUG mode.
    /// - **ndjson**: Newline-Delimited JSON format where each log message is a single-line JSON object.
    ///   Optimized for log aggregation systems like ELK Stack, Splunk, or CloudWatch.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // For development
    /// let devWriter = LogWriter(
    ///     metadata: [:],
    ///     logLevel: .debug,
    ///     logFormat: .console
    /// )
    ///
    /// // For production
    /// let prodWriter = LogWriter(
    ///     metadata: [:],
    ///     logLevel: .info,
    ///     logFormat: .ndjson
    /// )
    /// ```
    ///
    /// - Note: The `Sendable` conformance allows this enum to be safely used across
    ///         concurrency domains in Swift 6.
    public enum LogFormat: String, Sendable {
        /// Human-readable console format with formatted output.
        ///
        /// Format: `[LEVEL   ] Timestamp: Message | metadata | debug_info`
        ///
        /// Example:
        /// ```
        /// [INFO     ] Mon, 14 Oct 2025 10:30:45 GMT: User authenticated | ["user_id": "12345"]
        /// ```
        case console = "CONSOLE"

        /// Newline-Delimited JSON format (one JSON object per line).
        ///
        /// Each log message is encoded as a JSON object on a single line, suitable for
        /// log aggregation and analysis tools.
        ///
        /// Example:
        /// ```json
        /// {"level":"INFO","message":"User authenticated","metadata":{"user_id":"12345"},
        ///  "source":"Auth","date":"2025-10-14T10:30:45Z"}
        /// ```
        case ndjson = "NDJSON"
    }

    /// A circular buffer storing the most recent log messages.
    ///
    /// This buffer maintains a rolling history of the last 250 log messages, automatically
    /// discarding the oldest message when a new one is added beyond capacity. It's useful
    /// for debugging, testing, and runtime log inspection without file I/O.
    ///
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Access recent logs
    /// let logs = await logWriter.logBuffer.allElements()
    /// for log in logs {
    ///     print("\(log.level): \(log.message)")
    /// }
    /// ```
    ///
    /// - SeeAlso: ``lastLog`` for accessing only the most recent log message
    public let logBuffer = CircularBuffer<LogMessage>(capacity: 250)

    /// The most recently written log message.
    ///
    /// This property stores the last log message that was processed by this `LogWriter` instance.
    /// It provides quick access to the most recent log event, which is particularly useful in tests
    /// to verify that expected log messages were generated.
    ///
    /// ## Behavior
    ///
    /// This property only stores the reference to the most recent message. The actual push to
    /// ``logBuffer`` is performed synchronously by the ``log(level:message:metadata:source:file:function:line:)``
    /// method via ``pushToBuffer(_:)``, ensuring that the buffer is updated before the log call returns.
    /// This prevents race conditions in tests that immediately query the buffer.
    ///
    /// ## Concurrency
    ///
    /// This property is marked as `nonisolated` to allow access from any isolation domain
    /// in Swift 6. This is necessary for testing scenarios where logs may be generated from different
    /// actors or tasks.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // In test code
    /// logger.info("Test message")
    /// XCTAssertEqual(LogWriter.lastLog?.message, "Test message")
    /// XCTAssertEqual(LogWriter.lastLog?.level, "INFO")
    /// ```
    ///
    /// - Note: This feature is primarily designed for testing purposes. Production code should not
    ///         rely on this property for application logic.
    /// - Important: The value may be `nil` if no logs have been written since the writer was created.
    /// - SeeAlso: ``logBuffer`` for accessing a history of recent log messages
    /// - SeeAlso: ``pushToBuffer(_:)`` for the synchronous buffer push implementation
    nonisolated public var lastLog: LogMessage? {
        get {
            state.withLock { $0.lastLog }
        }
        set {
            state.withLock { $0.lastLog = newValue }

            if let newValue {
                // Push to buffer using a detached task to avoid blocking any executor
                // The waitForLog() method handles synchronization for tests that need it
                Task.detached {
                    await self.logBuffer.push(newValue)
                }
            }
        }
    }

    /// Searches the log buffer for the most recent log entry containing a specific string.
    ///
    /// This method traverses the circular buffer in reverse chronological order (newest to oldest)
    /// and returns the first log entry whose message contains the specified search string.
    ///
    /// ## Search Behavior
    ///
    /// - Performs a case-sensitive substring search on the log message field
    /// - Searches from newest to oldest entries in the buffer
    /// - Returns immediately when a match is found
    /// - Returns `nil` if no matching entry exists
    ///
    /// ## Performance
    ///
    /// The search is O(n) where n is the number of entries in the buffer (up to capacity of 250).
    /// The method is optimized to return early when a match is found.
    ///
    /// ## Thread Safety
    ///
    /// This method is async to safely access the actor-isolated buffer.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // In test code
    /// logger.info("User logged in successfully")
    /// logger.info("Token generated")
    ///
    /// // Search for specific log entry
    /// if let entry = await Log.writer.getLastLog(where: "User logged in") {
    ///     print("Found: \(entry.message)")
    ///     XCTAssertEqual(entry.level, "INFO")
    /// }
    /// ```
    ///
    /// - Parameter searchString: The string to search for within log message contents.
    ///                          This is a case-sensitive substring match.
    ///
    /// - Returns: The most recent ``LogMessage`` whose message field contains `searchString`,
    ///           or `nil` if no matching entry is found.
    ///
    /// - Note: This method is primarily designed for testing purposes. Production code should not
    ///         rely on this for application logic as it accesses global mutable state.
    /// - SeeAlso: ``lastLog`` for accessing only the most recent log without filtering
    /// - SeeAlso: ``logBuffer`` for direct buffer access
    public func getLastLog(where searchString: String) async -> LogMessage? {
        // Get all elements from the buffer (oldest to newest)
        let allLogs = await logBuffer.allElements()

        // If buffer is empty, return nil
        guard !allLogs.isEmpty else {
            return nil
        }

        // Search from newest to oldest (reverse order)
        for log in allLogs.reversed() where log.message.contains(searchString) {
            return log
        }

        return nil
    }

    /// Waits for a log entry containing the specified search string with a timeout.
    ///
    /// This method uses an intelligent waiting mechanism that suspends until a matching log entry
    /// is found or written, or until the timeout expires. If a matching entry already exists in
    /// the buffer, it returns immediately with the most recent one. Otherwise, it waits asynchronously
    /// for a new log entry matching the search string to be written.
    ///
    /// ## Smart Waiting Behavior
    ///
    /// - If a match exists: Returns the most recent matching log immediately
    /// - If no match exists: Suspends and waits for a matching log to be written
    /// - Times out after 5 seconds by default, throwing a `LogWaitTimeout` error
    /// - Uses Swift Concurrency continuations for efficient waiting (no polling or yielding)
    /// - Multiple tasks can wait for different search strings simultaneously
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // In a test, start waiting before the log is written
    /// Task {
    ///     do {
    ///         let log = try await Log.writer.waitForLog(where: "test-uuid-123")
    ///         #expect(log.message.contains("test-uuid-123"))
    ///     } catch {
    ///         Issue.record("Timeout waiting for log")
    ///     }
    /// }
    ///
    /// // Later, when the log is written, the waiting task automatically resumes
    /// Log.info("Test message test-uuid-123")
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe through actor isolation of the underlying circular buffer.
    /// Multiple concurrent calls are safe and will not interfere with each other.
    ///
    /// - Parameters:
    ///   - searchString: The substring to search for in log messages (case-sensitive)
    ///   - timeout: Maximum time to wait in seconds (default: 5 seconds)
    /// - Returns: The matching `LogMessage`
    /// - Throws: `LogWaitTimeout` if no matching log appears within the timeout period
    ///
    /// - Note: This method is primarily designed for testing purposes where you know a log
    ///         will eventually be written. For checking if a log exists without waiting,
    ///         use ``getLastLog(where:)`` instead.
    /// - SeeAlso: ``getLastLog(where:)`` for non-blocking search that returns nil if not found
    /// - SeeAlso: ``lastLog`` for accessing only the most recent log without filtering
    /// - SeeAlso: ``logBuffer`` for direct buffer access
    public func waitForLog(where searchString: String, timeout: TimeInterval = 5.0) async throws -> LogMessage {
        // Use Task.timeout pattern with async/await
        return try await withThrowingTaskGroup(of: LogMessage.self) { group in
            // Add the waitForElement task
            group.addTask {
                await self.logBuffer.waitForElement { log in
                    log.message.contains(searchString)
                }
            }

            // Add the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw LogWaitTimeout(searchString: searchString, timeout: timeout)
            }

            // Return the first result (either the log or timeout error)
            guard let result = try await group.next() else {
                throw LogWaitTimeout(searchString: searchString, timeout: timeout)
            }

            // Cancel the other task
            group.cancelAll()

            return result
        }
    }

    /// Error thrown when `waitForLog(where:timeout:)` times out
    public struct LogWaitTimeout: Error, CustomStringConvertible {
        public let searchString: String
        public let timeout: TimeInterval

        public var description: String {
            "Timeout after \(timeout)s waiting for log containing: \"\(searchString)\""
        }
    }

    /// Accesses or modifies a specific metadata value by key.
    ///
    /// This subscript provides convenient access to individual metadata items in the logger's
    /// metadata dictionary. It conforms to the `LogHandler` protocol requirement for metadata
    /// management.
    ///
    /// ## Value Semantics
    ///
    /// Following the `LogHandler` protocol requirements, this subscript treats metadata as a value type.
    /// Changes made through this subscript affect only this specific `LogWriter` instance, not any
    /// other loggers or the global logging configuration.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var writer = LogWriter(metadata: [:], logLevel: .info, logFormat: .console)
    ///
    /// // Set metadata
    /// writer[metadataKey: "request_id"] = "abc-123"
    /// writer[metadataKey: "user_id"] = "42"
    ///
    /// // Read metadata
    /// if let requestId = writer[metadataKey: "request_id"] {
    ///     print("Request ID: \(requestId)")
    /// }
    ///
    /// // Remove metadata
    /// writer[metadataKey: "user_id"] = nil
    /// ```
    ///
    /// - Parameter metadataKey: The key for the metadata item to access or modify.
    /// - Returns: The metadata value for the given key, or `nil` if no value exists.
    nonisolated public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            state.withLock { $0.metadata[metadataKey] }
        }
        set(newValue) {
            state.withLock { $0.metadata[metadataKey] = newValue }
        }
    }

    /// The complete metadata dictionary attached to this log handler.
    ///
    /// This property stores all metadata key-value pairs that will be included with every log message
    /// written by this handler. Metadata provides contextual information that helps with log filtering,
    /// searching, and analysis.
    ///
    /// ## Value Semantics
    ///
    /// Following the `LogHandler` protocol requirements, metadata must be treated as a value type.
    /// Changes to this property affect only this specific `LogWriter` instance. When a logger is copied
    /// (which happens when you get a logger from `LoggingSystem.bootstrap`), the metadata is also copied,
    /// ensuring isolation between different logger instances.
    ///
    /// ## Metadata Merging
    ///
    /// When a log message is written, the metadata from this property is merged with any per-message
    /// metadata passed to the ``log(level:message:metadata:source:file:function:line:)`` method.
    /// In case of key conflicts, local (per-message) metadata values are preserved and combined with
    /// global (handler) metadata values using dot notation.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var writer = LogWriter(
    ///     metadata: ["service": "auth", "version": "1.0"],
    ///     logLevel: .info,
    ///     logFormat: .ndjson
    /// )
    ///
    /// // Add more metadata
    /// writer.metadata["environment"] = "production"
    ///
    /// // Replace all metadata
    /// writer.metadata = ["service": "auth", "version": "2.0"]
    /// ```
    ///
    /// - Note: Metadata keys and values should be chosen to facilitate log analysis. Common examples
    ///         include service names, request IDs, user IDs, and environment identifiers.
    nonisolated public var metadata: Logger.Metadata {
        get {
            state.withLock { $0.metadata }
        }
        set {
            state.withLock { $0.metadata = newValue }
        }
    }

    /// The minimum log level for messages to be processed by this handler.
    ///
    /// This property determines which log messages will be processed based on their severity.
    /// Messages with a level below this threshold are discarded by the logging framework before
    /// reaching this handler, improving performance by avoiding unnecessary processing.
    ///
    /// ## Log Levels (from lowest to highest severity)
    ///
    /// - `trace`: Very detailed information, typically only for diagnosing problems
    /// - `debug`: Detailed information for debugging during development
    /// - `info`: General informational messages about application state
    /// - `notice`: Normal but significant events
    /// - `warning`: Warning messages for potentially harmful situations
    /// - `error`: Error events that might still allow the application to continue
    /// - `critical`: Critical conditions requiring immediate attention
    ///
    /// ## Value Semantics
    ///
    /// Following the `LogHandler` protocol requirements, the log level must be treated as a value type.
    /// Changes to this property affect only this specific `LogWriter` instance. The logging framework
    /// may provide global log level overrides, which means that changing this property might not always
    /// result in visible behavior changes if a global override is in effect.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var writer = LogWriter(metadata: [:], logLevel: .info, logFormat: .console)
    ///
    /// // Change log level to see more detail
    /// writer.logLevel = .debug
    ///
    /// // Reduce verbosity in production
    /// writer.logLevel = .warning
    /// ```
    ///
    /// - Note: It is acceptable for the logging system to provide a global log level override that
    ///         supersedes this per-handler setting.
    nonisolated public var logLevel: Logger.Level {
        get {
            state.withLock { $0.logLevel }
        }
        set {
            state.withLock { $0.logLevel = newValue }
        }
    }

    /// The output format used when writing log messages.
    ///
    /// This property controls how log messages are formatted when written to standard output.
    /// The format can be changed at runtime to switch between human-readable console output
    /// and machine-parseable JSON format.
    ///
    /// ## Available Formats
    ///
    /// - **console**: Human-readable format with aligned columns and timestamps, ideal for
    ///   development and debugging. In DEBUG builds, includes additional source location information.
    /// - **ndjson**: Newline-Delimited JSON format where each log is a single-line JSON object,
    ///   suitable for log aggregation systems and structured log analysis.
    ///
    /// ## Format Examples
    ///
    /// Console format:
    /// ```
    /// [INFO     ] Mon, 14 Oct 2025 10:30:45 GMT: Server started | ["port": "8080"]
    /// ```
    ///
    /// NDJSON format:
    /// ```json
    /// {"level":"INFO","message":"Server started","metadata":{"port":"8080"},"date":"2025-10-14T10:30:45Z"}
    /// ```
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var writer = LogWriter(metadata: [:], logLevel: .info, logFormat: .console)
    ///
    /// // Switch to NDJSON for production deployment
    /// writer.logFormat = .ndjson
    /// ```
    ///
    /// - SeeAlso: ``LogFormat`` for detailed format specifications
    nonisolated public var logFormat: LogFormat {
        get {
            state.withLock { $0.logFormat }
        }
        set {
            state.withLock { $0.logFormat = newValue }
        }
    }

    /// Emits a log message with full context information.
    ///
    /// This is the primary method of the `LogHandler` protocol and is called by the Swift Logging
    /// framework whenever a log message is written. It processes the message, applies filtering,
    /// merges metadata, handles special cases (like audit logs), and outputs the formatted result
    /// to standard output.
    ///
    /// ## Processing Steps
    ///
    /// 1. **Filtering**: Checks if the message matches any patterns in ``messagesSkipping`` and
    ///    silently discards it if so
    /// 2. **Metadata Merging**: Combines per-message metadata with handler-level metadata
    /// 3. **Message Generation**: Creates a ``LogMessage`` struct with all context
    /// 4. **Special Handling**: Applies audit log transformation if metadata contains `type: "audit"`
    /// 5. **Formatting**: Outputs the message according to the configured ``logFormat``
    /// 6. **Storage**: Updates ``lastLog`` and ``logBuffer`` with the new message
    ///
    /// ## Audit Log Support
    ///
    /// Messages with metadata containing `"type": "audit"` receive special treatment:
    /// - The level is changed to "AUDIT" in the output
    /// - The original level is preserved in metadata as "level"
    /// - The "type" key is removed from the final metadata
    ///
    /// ## Output Formats
    ///
    /// - **Console**: Aligned, human-readable format with optional debug information
    /// - **NDJSON**: Single-line JSON suitable for log aggregation tools
    ///
    /// ## Example
    ///
    /// ```swift
    /// let writer = LogWriter(metadata: [:], logLevel: .info, logFormat: .console)
    /// writer.log(
    ///     level: .info,
    ///     message: "User logged in",
    ///     metadata: ["user_id": "42", "ip": "192.168.1.1"],
    ///     source: "AuthModule",
    ///     file: #file,
    ///     function: #function,
    ///     line: #line
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - level: The severity level of the log message (trace, debug, info, notice, warning, error, critical).
    ///   - message: The log message content. Call `message.description` to get a string representation.
    ///   - metadata: Optional metadata specific to this log message. Will be merged with the handler's metadata.
    ///   - source: The source module or subsystem where the log originated (e.g., "Server", "Auth").
    ///   - file: The source file path where the log was written (typically from `#file`).
    ///   - function: The function name where the log was written (typically from `#function`).
    ///   - line: The line number where the log was written (typically from `#line`).
    ///
    /// - Note: In release builds, file, function, and line information is omitted from the output
    ///         to reduce log size and improve performance.
    /// - Note: The `fflush(stdout)` call was removed for Swift 6 concurrency compatibility.
    ///         The `print()` function already flushes on newlines.
    nonisolated public func log(// swiftlint:disable:this function_parameter_count
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Skip known messages
        if messagesSkipping.contains(message.description) {
            return
        }
        // local mutable copy of metadata - protected by mutex
        let (handlerMetadata, currentLogFormat) = state.withLock { ($0.metadata, $0.logFormat) }

        var localMetadata = metadata
        localMetadata?.merge(handlerMetadata) { localValue, globalValue in
            Logger.MetadataValue(stringLiteral: localValue.description + "." + globalValue.description)
        }
        // convert to encodable Dict
        let metaDict: Dictionary<String, String>? = localMetadata.flatMap({ meta in
            var dict: Dictionary<String, String> = [:]
            meta.keys.forEach { key in
                dict[key] = meta[key]?.description
            }
            return dict
        })

        // generate the log message
        var logMessage = generateLogMessage(
            level: level,
            message: message.description,
            metadata: metaDict,
            source: source,
            file: file,
            function: function,
            line: line
        )

        // Transformation based on metadata
        if logMessage.metadata?["type"] == "audit" {
            let level = logMessage.level
            logMessage.level = "audit".uppercased()
            logMessage.metadata?["level"] = level.uppercased()
        }
        logMessage.metadata = logMessage.metadata?.filter { key, _ in
            key != "type"
        }

        // Log for different formats to stdout
        switch currentLogFormat {
        case .ndjson:
            do {
                let jsonData = try JSONEncoder.main.encode(logMessage)
                if let logString = String(data: jsonData, encoding: .utf8) {
                    print(logString.replacingOccurrences(of: "\n", with: "", options: .caseInsensitive))
                }
            } catch {
                print("ATTENTION: can't write ndjson | [\(level.name)] \(message)")
            }
        default:
            let printLevel = "[\(logMessage.level)]".padding(toLength: 11, withPad: " ", startingAt: 0)
            let printMetadata = (
                logMessage.metadata?.count ?? 0 > 0 ? " | " : " "
            ) + (logMessage.metadata?.description ?? "")
            var debugLog = ""
            #if DEBUG
            debugLog = " | \(logMessage.function ?? "")"
                + " in \(logMessage.file ?? ""):\(String(logMessage.line ?? 0))"
            #endif
            print("\(printLevel)\(logMessage.date.rfc1123): \(logMessage.message)\(printMetadata)\(debugLog)")
        }

        // Set lastLog which will asynchronously push to buffer via Task.detached
        lastLog = logMessage

        // Force flush stdout to ensure logs appear immediately in containerized environments
        // where stdout may be buffered even though it's not a TTY.
        try? FileHandle.standardOutput.synchronize()
    }

    // swiftlint:disable function_parameter_count
    /// Constructs a `LogMessage` struct with build-specific behavior.
    ///
    /// This private helper method creates a ``LogMessage`` instance with all provided context information.
    /// It employs conditional compilation to optimize log output based on the build configuration:
    /// DEBUG builds include full source location details for debugging, while release builds omit
    /// this information to reduce log size and avoid exposing internal implementation details.
    ///
    /// ## Build Configuration Behavior
    ///
    /// - **DEBUG Builds**: Includes file path, function name, and line number in the returned message.
    ///   This enables developers to quickly locate the source of log messages during development.
    /// - **Release Builds**: Sets file, function, and line to `nil` to minimize log payload size
    ///   and prevent leaking source code structure information in production logs.
    ///
    /// ## Parameter Processing
    ///
    /// - The log level is converted to an uppercase string representation (e.g., "INFO", "ERROR")
    /// - The message is converted to its string description
    /// - All other parameters are passed through as-is to the `LogMessage` initializer
    ///
    /// ## Usage
    ///
    /// This method is called internally by the ``log(level:message:metadata:source:file:function:line:)``
    /// method and is not intended to be called directly by external code.
    ///
    /// ```swift
    /// let logMsg = generateLogMessage(
    ///     level: .info,
    ///     message: "Operation completed",
    ///     metadata: ["duration": "150ms"],
    ///     source: "Server",
    ///     file: "/path/to/file.swift",
    ///     function: "processRequest()",
    ///     line: 42
    /// )
    /// // In DEBUG: all fields populated
    /// // In RELEASE: file, function, line are nil
    /// ```
    ///
    /// - Parameters:
    ///   - level: The severity level of the log message.
    ///   - message: The log message content as a string.
    ///   - metadata: Optional dictionary of key-value pairs providing additional context.
    ///   - source: The source module or component that generated the log.
    ///   - file: The source file path where the log was emitted (omitted in release builds).
    ///   - function: The function name where the log was emitted (omitted in release builds).
    ///   - line: The line number where the log was emitted (omitted in release builds).
    ///
    /// - Returns: A fully constructed ``LogMessage`` instance with build-appropriate field population.
    ///
    /// - Note: The conditional compilation ensures zero runtime overhead for source location
    ///         handling in release builds, as the fields are simply not populated.
    private func generateLogMessage(level: Logger.Level,
                                    message: String,
                                    metadata: Dictionary<String, String>?,
                                    source: String?,
                                    file: String?,
                                    function: String?,
                                    line: UInt) -> LogMessage {
        #if DEBUG
        return LogMessage(
            level: level.name.uppercased(),
            message: message.description,
            metadata: metadata,
            source: source,
            file: file,
            function: function,
            line: line
        )
        #else
        return LogMessage(
            level: level.name.uppercased(),
            message: message.description,
            metadata: metadata,
            source: source,
            file: nil,
            function: nil,
            line: nil
        )
        #endif
    }

    // swiftlint:enable function_parameter_count
}
