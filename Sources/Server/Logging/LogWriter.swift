import Foundation
import Logging

/// A Log handler that writes logs in a specific format and hold the last log message in a variable for later evaluation
public struct LogWriter: LogHandler {

    /// Define messages that should be skipped silently
    private let messagesSkipping: [String] = [
        // Info from JWT when no token is set, but this is a common scenario and should not float the log
        "Request is missing JWT bearer header"
    ]

    public init(metadata: Logger.Metadata, logLevel: Logger.Level, logFormat: LogFormat) {
        self.metadata = metadata
        self.logLevel = logLevel
        self.logFormat = logFormat
        JSONEncoder.main.dateEncodingStrategy = .iso8601
    }

    /// The last log message is stored in `lastLog` with the structure of `LogMessage`
    /// - SeeAlso: LogMessage
    public struct LogMessage: Encodable {
        var level: String
        let message: String
        var metadata: Dictionary<String, String>?
        let source: String?
        let file: String?
        let function: String?
        let line: UInt?
        let date: Date = Date()
    }

    public enum LogFormat: String {
        case console = "CONSOLE"
        case ndjson = "NDJSON"
    }

    /// An internal Buffer to store the last n'th log messages
    public static var logBuffer = CircularBuffer<LogMessage>(capacity: 250)

    /// Stores the static last log message that is written to the logger and can be recalled by any
    /// function with `LogWriter.lastlog`
    /// - Note: This feature is mostly for testing purposes
    public static var lastLog: LogMessage? {
        didSet {
            if let lastLog {
                LogWriter.logBuffer.push(lastLog)
            }
        }
    }

    /// Add, remove, or change the logging metadata.
    /// Note: LogHandlers must treat logging metadata as a value type. This means that the change in
    /// metadata must only affect this very LogHandler.
    /// Parameters:
    ///     - metadataKey: The key for the metadata item
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set(newValue) {
            metadata[metadataKey] = newValue
        }
    }

    /// Get or set the entire metadata storage as a dictionary.
    ///
    /// - note: `LogWriter`s must treat logging metadata as a value type. This means that the change in metadata must
    ///         only affect this very `LogHandler`.
    public var metadata: Logger.Metadata

    /// Get or set the configured log level.
    ///
    /// - note: `LogWriter`s must treat the log level as a value type. This means that the change in metadata must
    ///         only affect this very `LogWriter`. It is acceptable to provide some form of global log level override
    ///         that means a change in log level on a particular `LogHandler` might not be reflected in any
    ///        `LogHandler` implementation.
    public var logLevel: Logger.Level

    /// Get or set the log format.
    ///
    /// - console -  Logs a plain log sting in the format of `[ level ] Message`
    /// - ndjson - Logs detailed information as a one line json string.
    public var logFormat: LogFormat

    ///  Emit a log message.
    ///
    /// - Parameters:
    ///     - level: The log level the message was logged at.
    ///     - message: The message to log. To obtain a `String` representation call `message.description`.
    ///     - metadata: The metadata associated to this log message.
    ///     - source: The source where the log message originated, for example the logging module.
    ///     - file: The file the log message was emitted from.
    ///     - function: The function the log line was emitted from.
    ///     - line: The line the log message was emitted from.
    public func log(// swiftlint:disable:this function_parameter_count
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
        // local mutable copy of metadata
        var localMetadata = metadata
        localMetadata?.merge(self.metadata) { localValue, globalValue in
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
        switch logFormat {
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
                    logMessage.metadata?.count ?? 0 > 0 ? " | " : ""
            ) + (logMessage.metadata?.description ?? "")
            var debugLog = ""
            if Constants.isRelease == false {
                debugLog = " | \(logMessage.function ?? "")"
                        + "in \(logMessage.file ?? ""):\(String(logMessage.line ?? 0))"
            }
            print("\(printLevel)\(logMessage.date.rfc1123): \(logMessage.message)\(printMetadata)\(debugLog)")
        }
        LogWriter.lastLog = logMessage
        fflush(stdout)
    }

    // swiftlint:disable function_parameter_count
    /// Generate different log messages for release or development
    ///
    /// - Parameters:
    ///   - level: The `Logger.Level` of the log `message`
    ///   - message: The message to log
    ///   - metadata: A Dictionary with extra information
    ///   - source: The source package where the log was written
    ///   - file: The file in which the log message was written
    ///   - function: The function in which the log message was written
    ///   - line: The exact line of code where the log message was written
    /// - Returns: A constructed `LogMessage`
    private func generateLogMessage(level: Logger.Level,
                                    message: String,
                                    metadata: Dictionary<String, String>?,
                                    source: String?,
                                    file: String?,
                                    function: String?,
                                    line: UInt) -> LogMessage {
        switch Constants.isRelease {
        case true:
            return LogMessage(
                    level: level.name.uppercased(),
                    message: message.description,
                    metadata: metadata,
                    source: source,
                    file: nil,
                    function: nil,
                    line: nil
            )
        case false:
            return LogMessage(
                    level: level.name.uppercased(),
                    message: message.description,
                    metadata: metadata,
                    source: source,
                    file: file,
                    function: function,
                    line: line
            )
        }
    }

    // swiftlint:enable function_parameter_count
}
