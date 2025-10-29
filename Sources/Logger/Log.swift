import Foundation
import Logging

/// A project-wide global logging facility for the Uitsmijter application.
///
/// `Log` provides a centralized, thread-safe logging interface that wraps Apple's Unified Logging system
/// through the SwiftLog framework. It implements a singleton pattern and supports multiple log levels,
/// formats, and automatic request context enrichment.
///
/// ## Overview
///
/// The Log struct serves as the primary logging mechanism throughout the Uitsmijter codebase. It provides:
/// - Static logging methods for all standard log levels (debug, info, notice, warning, error, critical)
/// - Automatic metadata enrichment with request id
/// - Configurable log levels via environment variables
/// - Support for both console and structured (JSON) log formats
/// - A separate audit logger for login logs
///
/// ## Usage
///
/// ```swift
/// // Basic logging
/// Log.info("Server started successfully")
///
/// // Logging with request id
/// Log.warning("Invalid token received", requestId: req.id)
///
/// // Different log levels
/// Log.debug("Processing user authentication")
/// Log.error("Database connection failed")
/// Log.critical("System shutdown initiated")
/// ```
///
/// ## Configuration
///
/// The logger can be configured through environment variables:
/// - `LOG_LEVEL`: Sets the minimum log level (debug, info, notice, warning, error, critical)
/// - `LOG_FORMAT`: Sets the output format (console or json)
///
/// ## Thread Safety
///
/// The static logger properties are marked as `nonisolated(unsafe)` to allow access from any isolation
/// domain. While this bypasses Swift's strict concurrency checking, the underlying SwiftLog Logger
/// type is thread-safe by design and can be safely accessed from multiple concurrent contexts.
///
/// The Logger type from SwiftLog is explicitly documented as thread-safe and designed for this pattern.
/// Using `nonisolated(unsafe)` is the recommended approach per SwiftLog's Swift 6 migration guide.
///
/// - Note: Use the static logging methods directly (e.g., `Log.info("message")`).
///
public struct Log: Sendable {

    /// Internal storage for the configured log level string from environment.
    ///
    /// This property reads the `LOG_LEVEL` environment variable at initialization time. It is used internally
    /// by the `logLevel` computed property to determine the active log level.
    private static let useLevel: String? = ProcessInfo.processInfo.environment["LOG_LEVEL"]

    /// The active log level for the application.
    ///
    /// This computed property determines the minimum severity level for log messages. Messages below
    /// this level will be filtered out and not written to the log.
    ///
    /// The log level is determined by the `LOG_LEVEL` environment variable. Valid values are:
    /// - `debug`: Most verbose, includes all messages
    /// - `info`: Informational messages and above (default)
    /// - `notice`: Notable events and above
    /// - `warning`: Warning messages and above
    /// - `error`: Error messages and above
    /// - `critical`: Only critical system failures
    ///
    /// If the environment variable is not set or contains an invalid value, the default level is `.info`.
    ///
    /// - Returns: The configured `Logger.Level`, or `.info` as the default.
    static var logLevel: Logger.Level {
        guard let levelName = useLevel else {
            return .info
        }
        guard let level = Logger.Level(rawValue: levelName) else {
            return .info
        }
        return level
    }

    /// The active log format for the application.
    ///
    /// This computed property determines how log messages are formatted when written to output.
    ///
    /// The log format is determined by the `LOG_FORMAT` environment variable. Valid values are:
    /// - `CONSOLE` or `console`: Human-readable console format (default)
    /// - `JSON` or `json`: Structured JSON format for machine parsing
    ///
    /// The JSON format is particularly useful for log aggregation systems and monitoring tools
    /// that can parse structured logs. The console format is more readable for local development.
    ///
    /// If the environment variable is not set or contains an invalid value, the default format
    /// is `.console`.
    ///
    /// - Returns: The configured `LogWriter.LogFormat`, or `.console` as the default.
    static var logFormat: LogWriter.LogFormat {
        guard let format = LogWriter.LogFormat(
            rawValue: ProcessInfo.processInfo.environment["LOG_FORMAT"]?.uppercased() ?? "console"
        )
        else {
            return .console
        }
        return format
    }

    /// The internal static logger instance for general application logging.
    ///
    /// This is the underlying `Logger` instance used by all static logging methods (debug, info, notice,
    /// warning, error, critical). It is initialized with:
    /// - Label: "Uitsmijter"
    /// - Metadata: `["type": "log"]` to distinguish from audit logs
    /// - Log level: Configured via `logLevel` property
    /// - Log format: Configured via `logFormat` property
    ///
    /// - Important: Use the public static logging methods (e.g., `Log.info()`) rather than accessing
    ///              this property directly.
    private static let logger = Logger(label: "Uitsmijter", factory: { _ in
        LogWriter(metadata: ["type": "log"], logLevel: logLevel, logFormat: logFormat)
    })

    /// The dedicated audit logger for security and compliance events.
    ///
    /// This logger is specifically designed for audit trail logging, capturing security-relevant events
    /// such as authentication attempts, authorization decisions, and access control changes. It maintains
    /// a separate log stream to facilitate compliance reporting and security analysis.
    ///
    /// The audit logger is initialized with:
    /// - Label: "Uitsmijter/audit"
    /// - Metadata: `["type": "audit"]` to distinguish from general application logs
    /// - Log level: Configured via `logLevel` property (same as main logger)
    /// - Log format: Configured via `logFormat` property (same as main logger)
    ///
    /// ## Usage
    ///
    /// ```swift
    /// Log.audit.info("User authentication successful", metadata: [
    ///     "user_id": "\(userId)",
    ///     "client_id": "\(clientId)",
    ///     "ip_address": "\(ipAddress)"
    /// ])
    /// ```
    ///
    /// - Important: Use this logger for security and compliance events. Use the main logger
    ///              for general application events.
    public static let audit = Logger(label: "Uitsmijter/audit", factory: { _ in
        LogWriter(metadata: ["type": "audit"], logLevel: logLevel, logFormat: logFormat)
    })

    /// Private initializer to prevent instantiation.
    ///
    /// The Log struct is designed to be used exclusively through its static methods.
    /// No instances should be created.
    private init() {}

    /// Returns a Logger instance for use with external libraries.
    ///
    /// This method provides access to the underlying SwiftLog `Logger` instance for integration
    /// with external libraries and frameworks that require a Logger parameter (such as Soto AWS SDK,
    /// Kubernetes client, Vapor Application, etc.).
    ///
    /// - Returns: The configured `Logger` instance for general application logging.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use with Vapor
    /// app.logger = Log.shared
    ///
    /// // Use with AWS SDK
    /// let s3Client = AWSClient(logger: Log.shared)
    ///
    /// // Use with Kubernetes client
    /// let kubeClient = KubernetesClient(logger: Log.shared)
    /// ```
    ///
    /// - Note: For application logging, prefer using the static methods like `Log.info()`, `Log.error()`,
    ///         etc. This property is primarily for library integration.
    public static var shared: Logger {
        logger
    }

    // MARK: - Log Helper

    /// Enriches log metadata with request-specific context information.
    ///
    /// This helper method augments log messages with contextual information such as a request ID.
    /// It adds the request ID to the metadata, which helps correlate log entries related
    /// to the same HTTP request or operation across the application.
    ///
    /// The method starts with any metadata provided by the logger's metadata provider, then adds
    /// request-specific information if a request ID is provided.
    ///
    /// - Parameter requestId: An optional request identifier string. If `nil`, only the base
    ///                        metadata from the logger's provider is returned.
    ///
    /// - Returns: A `Logger.Metadata` dictionary containing:
    ///            - All metadata from the logger's metadata provider
    ///            - `"request"`: The unique request ID (if requestId is provided)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Without request context
    /// let metadata = enrichMetadata(with: nil)
    /// // Returns: [:]
    ///
    /// // With request context
    /// let metadata = enrichMetadata(with: "3B7A9C2E-1F4D-4B8A-9E2C-5D6F7A8B9C0D")
    /// // Returns: ["request": "3B7A9C2E-1F4D-4B8A-9E2C-5D6F7A8B9C0D"]
    /// ```
    private static func enrichMetadata(with requestId: String?) -> Logger.Metadata {
        var metadata: Logger.Metadata = Log.logger.metadataProvider?.get() ?? [:]
        if let requestId {
            metadata["request"] = Logger.MetadataValue(stringLiteral: requestId)
        }
        return metadata
    }

    /// Logs a debug-level message.
    ///
    /// Debug messages are used for detailed diagnostic information useful during development and
    /// troubleshooting. These messages are typically disabled in production environments and should
    /// contain information helpful for understanding application flow and state.
    ///
    /// The message is automatically sanitized to replace newlines with spaces, ensuring clean log
    /// output. If a request is provided, the request ID is automatically added to the log metadata.
    ///
    /// - Parameters:
    ///   - msg: The debug message to log. Multiline strings are supported and will be converted
    ///          to a single line.
    ///   - requestId: An optional request identifier string. If provided, the request ID will be included
    ///                in the log metadata for correlation. Defaults to `nil`.
    ///   - file: The file identifier where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///   - function: The function name where the log call originated. Automatically populated by the
    ///               compiler. Do not provide this parameter manually.
    ///   - line: The line number where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Basic debug logging
    /// Log.debug("Processing authentication request")
    ///
    /// // Debug logging with request context
    /// Log.debug("Token validation started for user: \(userId)", requestId: req.id)
    ///
    /// // Multiline debug message (newlines will be converted to spaces)
    /// Log.debug("""
    ///     User details:
    ///     - ID: \(userId)
    ///     - Email: \(email)
    ///     - Role: \(role)
    ///     """)
    /// ```
    public static func debug(
        _ msg: String,
        requestId: String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.debug(
            .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
            metadata: enrichMetadata(with: requestId),
            file: file, function: function, line: line
        )
    }

    /// Logs an informational message.
    ///
    /// Info messages communicate general informational events that highlight the progress or state
    /// of the application. These messages are typically enabled in production and should provide
    /// useful context about application behavior without being overly verbose.
    ///
    /// The message is automatically sanitized to replace newlines with spaces, ensuring clean log
    /// output. If a request is provided, the request ID is automatically added to the log metadata.
    ///
    /// - Parameters:
    ///   - msg: The informational message to log. Multiline strings are supported and will be
    ///          converted to a single line.
    ///   - requestId: An optional request identifier string. If provided, the request ID will be included
    ///                in the log metadata for correlation. Defaults to `nil`.
    ///   - file: The file identifier where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///   - function: The function name where the log call originated. Automatically populated by the
    ///               compiler. Do not provide this parameter manually.
    ///   - line: The line number where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Basic info logging
    /// Log.info("Server started successfully on port 8080")
    ///
    /// // Info logging with request context
    /// Log.info("User logged in successfully", requestId: req.id)
    ///
    /// // Logging application state changes
    /// Log.info("Tenant configuration reloaded: \(tenantCount) tenants active")
    /// ```
    public static func info(
        _ msg: String,
        requestId: String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.info(
            .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
            metadata: enrichMetadata(with: requestId),
            file: file, function: function, line: line
        )
    }

    /// Logs a notice-level message.
    ///
    /// Notice messages represent significant events that are more important than general information
    /// but not problematic. They highlight noteworthy circumstances or state changes that operators
    /// should be aware of, such as configuration changes or important operational milestones.
    ///
    /// The message is automatically sanitized to replace newlines with spaces, ensuring clean log
    /// output. If a request is provided, the request ID is automatically added to the log metadata.
    ///
    /// - Parameters:
    ///   - msg: The notice message to log. Multiline strings are supported and will be converted
    ///          to a single line.
    ///   - requestId: An optional request identifier string. If provided, the request ID will be included
    ///                in the log metadata for correlation. Defaults to `nil`.
    ///   - file: The file identifier where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///   - function: The function name where the log call originated. Automatically populated by the
    ///               compiler. Do not provide this parameter manually.
    ///   - line: The line number where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Configuration changes
    /// Log.notice("Redis connection pool size changed from 10 to 20")
    ///
    /// // Important operational events
    /// Log.notice("Graceful shutdown initiated", requestId: req.id)
    ///
    /// // Significant state transitions
    /// Log.notice("Failover to backup authentication provider completed")
    /// ```
    public static func notice(
        _ msg: String,
        requestId: String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.notice(
            .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
            metadata: enrichMetadata(with: requestId),
            file: file, function: function, line: line
        )
    }

    /// Logs a warning-level message.
    ///
    /// Warning messages indicate potentially problematic situations that do not prevent the application
    /// from functioning but may require attention. These could include deprecated API usage, recoverable
    /// errors, or unexpected but handled conditions.
    ///
    /// The message is automatically sanitized to replace newlines with spaces, ensuring clean log
    /// output. If a request is provided, the request ID is automatically added to the log metadata.
    ///
    /// - Parameters:
    ///   - msg: The warning message to log. Multiline strings are supported and will be converted
    ///          to a single line.
    ///   - requestId: An optional request identifier string. If provided, the request ID will be included
    ///                in the log metadata for correlation. Defaults to `nil`.
    ///   - file: The file identifier where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///   - function: The function name where the log call originated. Automatically populated by the
    ///               compiler. Do not provide this parameter manually.
    ///   - line: The line number where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Recoverable errors
    /// Log.warning("Failed to connect to Redis, falling back to in-memory storage")
    ///
    /// // Invalid input that was handled
    /// Log.warning("Invalid redirect URI provided, using default", requestId: req.id)
    ///
    /// // Deprecated usage
    /// Log.warning("Client using deprecated OAuth flow: implicit grant")
    /// ```
    public static func warning(
        _ msg: String,
        requestId: String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.warning(
            .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
            metadata: enrichMetadata(with: requestId),
            file: file, function: function, line: line
        )
    }

    /// Logs an error-level message.
    ///
    /// Error messages indicate failures or exceptional conditions that prevent a specific operation
    /// from completing successfully. While the application continues to run, these events represent
    /// genuine problems that typically require investigation and remediation.
    ///
    /// The message is automatically sanitized to replace newlines with spaces, ensuring clean log
    /// output. If a request is provided, the request ID is automatically added to the log metadata.
    ///
    /// - Parameters:
    ///   - msg: The error message to log. Multiline strings are supported and will be converted
    ///          to a single line.
    ///   - requestId: An optional request identifier string. If provided, the request ID will be included
    ///                in the log metadata for correlation. Defaults to `nil`.
    ///   - file: The file identifier where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///   - function: The function name where the log call originated. Automatically populated by the
    ///               compiler. Do not provide this parameter manually.
    ///   - line: The line number where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Database errors
    /// Log.error("Failed to query user database: \(error.localizedDescription)")
    ///
    /// // Authentication failures
    /// Log.error("Token signature verification failed", requestId: req.id)
    ///
    /// // Resource failures
    /// Log.error("Unable to load tenant configuration from file: \(filePath)")
    /// ```
    public static func error(
        _ msg: String,
        requestId: String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.error(
            .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
            metadata: enrichMetadata(with: requestId),
            file: file, function: function, line: line
        )
    }

    /// Logs a critical-level message.
    ///
    /// Critical messages represent severe error conditions that may lead to application failure or
    /// data loss. These are the highest severity events and typically indicate situations requiring
    /// immediate attention, such as system failures, security breaches, or data corruption.
    ///
    /// The message is automatically sanitized to replace newlines with spaces, ensuring clean log
    /// output. If a request is provided, the request ID is automatically added to the log metadata.
    ///
    /// - Parameters:
    ///   - msg: The critical error message to log. Multiline strings are supported and will be
    ///          converted to a single line.
    ///   - requestId: An optional request identifier string. If provided, the request ID will be included
    ///                in the log metadata for correlation. Defaults to `nil`.
    ///   - file: The file identifier where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///   - function: The function name where the log call originated. Automatically populated by the
    ///               compiler. Do not provide this parameter manually.
    ///   - line: The line number where the log call originated. Automatically populated by the
    ///           compiler. Do not provide this parameter manually.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // System failures
    /// Log.critical("Out of memory: unable to allocate resources")
    ///
    /// // Security incidents
    /// Log.critical("Potential security breach detected: unauthorized token generation", requestId: req.id)
    ///
    /// // Data integrity issues
    /// Log.critical("Database corruption detected in tenant table")
    ///
    /// // Fatal configuration errors
    /// Log.critical("Required JWT signing key not found - cannot start application")
    /// ```
    public static func critical(
        _ msg: String,
        requestId: String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line) {
        Log.logger.critical(
            .init(stringLiteral: msg.replacingOccurrences(of: "\n", with: " ")),
            metadata: enrichMetadata(with: requestId),
            file: file, function: function, line: line
        )
    }

}
