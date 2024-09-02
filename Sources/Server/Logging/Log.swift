import Foundation
import Logging
import Vapor

/// A project wide global logger
/// - Note: Singleton
///
struct Log {
    /// The global main logger
    static var main = Log()

    static var useLevel: String? = Environment.get("LOG_LEVEL")

    /// Log level of the project, set via environment parameter `LOG_LEVEL`
    static var logLevel: Logger.Level {
        guard let levelName = useLevel else {
            return .info
        }
        guard let level = Logger.Level(levelName) else {
            return .info
        }
        return level
    }

    /// Log format of the project, set via environment parameter `LOG_FORMAT`
    static var logFormat: LogWriter.LogFormat {
        guard let format = LogWriter.LogFormat(
                rawValue: Environment.get("LOG_FORMAT")?.uppercased() ?? "console"
        )
        else {
            return .console
        }
        return format
    }

    /// A static Logger
    /// - Important: Use: `Logging.logger.*` to log,
    private static var logger = Logger(label: "\(Constants.APPLICATION)/\(Constants.MAJOR_VERSION)", factory: { _ in
        LogWriter(metadata: ["type": "log"], logLevel: logLevel, logFormat: logFormat)
    })

    /// A static Logger
    /// - Important: Use: `Logging.logger.*` to log,
    ///
    static var audit = Logger(label: "\(Constants.APPLICATION)/\(Constants.MAJOR_VERSION)", factory: { _ in
        LogWriter(metadata: ["type": "audit"], logLevel: logLevel, logFormat: logFormat)
    })

    /// Returns the logger
    /// - Returns: the logger
    mutating func getLogger() -> Logger {
        Log.logger
    }

    /// Private init
    private init() {
        Log.logger.logLevel = Log.logLevel
        Log.logger.info("Current Loglevel is [\(Log.logLevel)]")
    }

    #if DEBUG
    /// For testing purpose only
    /// set: `Log.main = Log(level: Logger.Level.error)`
    /// - Parameter logLevel: a valid Logger.Level
    init(level logLevel: Logger.Level) {
        Log.logger.logLevel = logLevel
        Log.logger.info("Current Loglevel is [\(logLevel.description)]")
        Log.useLevel = logLevel.name
    }
    #endif

    // MARK: - Log Helper

    /// Enrich the log message with metadata of the request
    ///
    /// - Parameter request: The current request
    /// - Returns: Metadata Log Object
    private static func enrichMetadata(with request: Request?) -> Logger.Metadata {
        var metadata: Logger.Metadata = Log.logger.metadataProvider?.get() ?? [:]
        if let request {
            metadata["request"] = Logger.MetadataValue(stringLiteral: request.id)
            if let tenant = request.clientInfo?.tenant {
                metadata["tenant"] = Logger.MetadataValue(stringLiteral: tenant.name)
            }
            if let client = request.clientInfo?.client {
                metadata["client"] = Logger.MetadataValue(stringLiteral: client.name)
            }
        }
        return metadata
    }

    /// Log to Debug
    ///
    /// - Parameter
    ///     - msg: Accept multiline string
    ///     - request: Optional Request Object
    static func debug(
        _ msg: String,
        request: Request? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.debug(
                .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
                metadata: enrichMetadata(with: request),
                file: file, function: function, line: line
        )
    }

    /// Log to Info
    ///
    /// - Parameter
    ///     - msg: Accept multiline string
    ///     - request: Optional Request Object
    static func info(
        _ msg: String,
        request: Request? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.info(
                .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
                metadata: enrichMetadata(with: request),
                file: file, function: function, line: line
        )
    }

    /// Log to Notice
    ///
    /// - Parameter
    ///     - msg: Accept multiline string
    ///     - request: Optional Request Object
    static func notice(
        _ msg: String,
        request: Request? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.notice(
                .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
                metadata: enrichMetadata(with: request),
                file: file, function: function, line: line
        )
    }

    /// Log to Warning
    ///
    /// - Parameter
    ///      - msg: Accept multiline string
    ///      - request: Optional Request Object
    static func warning(
        _ msg: String,
        request: Request? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.warning(
                .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
                metadata: enrichMetadata(with: request),
                file: file, function: function, line: line
        )
    }

    /// Log to Error
    ///
    /// - Parameter
    ///      - msg: Accept multiline string
    ///      - request: Optional Request Object
    static func error(
        _ msg: String,
        request: Request? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.error(
                .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
                metadata: enrichMetadata(with: request),
                file: file, function: function, line: line
        )
    }

    /// Log to Critical
    ///
    /// - Parameter msg: Accept multiline string
    ///      - request: Optional Request Object
    static func critical(
        _ msg: String,
        request: Request? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.critical(
                .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
                metadata: enrichMetadata(with: request),
                file: file, function: function, line: line
        )
    }

}
