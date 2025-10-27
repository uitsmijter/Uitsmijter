import Foundation
import Logging

/// Extensions to support Logger functionality without Vapor dependency
extension Logger.Level {
    /// Returns the string name of the log level.
    ///
    /// This property provides a string representation of the log level that can be used
    /// for initialization from strings or for display purposes.
    ///
    /// - Returns: The lowercase string name of the log level (e.g., "trace", "debug", "info").
    var name: String {
        switch self {
        case .trace: return "trace"
        case .debug: return "debug"
        case .info: return "info"
        case .notice: return "notice"
        case .warning: return "warning"
        case .error: return "error"
        case .critical: return "critical"
        }
    }

    /// Initialize a Logger.Level from a string name.
    ///
    /// This initializer allows creating a log level from a string representation,
    /// useful when reading from configuration or environment variables.
    ///
    /// - Parameter rawValue: The string name of the log level (case insensitive).
    /// - Returns: The corresponding Logger.Level, or nil if the string doesn't match any level.
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "trace": self = .trace
        case "debug": self = .debug
        case "info": self = .info
        case "notice": self = .notice
        case "warning": self = .warning
        case "error": self = .error
        case "critical": self = .critical
        default: return nil
        }
    }
}

extension Date {
    /// Returns the date formatted as RFC 1123 string.
    ///
    /// RFC 1123 format is commonly used in HTTP headers and logs.
    /// Example: "Mon, 14 Oct 2025 10:30:45 GMT"
    ///
    /// - Returns: A string representation of the date in RFC 1123 format.
    var rfc1123: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }
}
