import Foundation

/// Errors that can occur during redirect URI operations.
///
/// These errors represent failures in processing or validating redirect URIs
/// used in OAuth2 authentication flows.
///
/// ## Error Cases
///
/// - ``notAnUrl(_:)``: Value cannot be converted to a valid URL
///
/// ## Usage
///
/// ```swift
/// do {
///     let redirectUri = try RedirectUri(from: userInput)
/// } catch RedirectError.notAnUrl(let value) {
///     logger.error("Invalid URL format: \(value)")
/// }
/// ```
///
/// - SeeAlso: ``RedirectUri``, ``RedirectUriProtocol``
enum RedirectError: Error {
    /// Indicates that the provided value could not be converted to a valid URL.
    ///
    /// This error occurs when attempting to create a redirect URI from a string
    /// or other value that does not represent a valid URL format.
    ///
    /// - Parameter value: The value that failed to convert to a URL.
    ///
    /// ## Common Causes
    /// - Malformed URL string (missing scheme, invalid characters, etc.)
    /// - Empty or whitespace-only input
    /// - Unsupported URL scheme
    ///
    /// ## Resolution
    /// Ensure the redirect URI is properly formatted:
    /// - Include scheme (http:// or https://)
    /// - Valid domain name or IP address
    /// - Properly encoded special characters
    case notAnUrl(any Sendable)
}
