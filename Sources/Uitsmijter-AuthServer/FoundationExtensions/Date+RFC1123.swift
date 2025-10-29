import Foundation

/// RFC 1123 date formatting extension for Date
///
/// This extension provides RFC 1123 date formatting, which is commonly used in
/// HTTP headers, logs, and standardized date representations.
///
/// ## Format
///
/// RFC 1123 uses the format: `EEE, dd MMM yyyy HH:mm:ss z`
///
/// Example: `Mon, 14 Oct 2025 10:30:45 GMT`
///
/// ## Usage
///
/// ```swift
/// let date = Date()
/// let formatted = date.rfc1123
/// print(formatted)  // "Mon, 29 Oct 2025 12:34:56 GMT"
/// ```
///
/// - SeeAlso: [RFC 1123](https://tools.ietf.org/html/rfc1123)
extension Date {
    /// Returns the date formatted as an RFC 1123 string.
    ///
    /// RFC 1123 format is the standard date format used in HTTP headers
    /// and many internet protocols.
    ///
    /// - Returns: A string representation of the date in RFC 1123 format (GMT timezone).
    var rfc1123: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }
}
