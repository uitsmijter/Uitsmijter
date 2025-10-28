import Foundation

// MARK: - Response Error

/// Structured error response sent to clients when operations fail.
///
/// This structure provides a consistent error response format across all API endpoints
/// and error pages. It includes HTTP status codes, error descriptions, and contextual
/// information about the failed request.
///
/// ## JSON Response Format
///
/// ```json
/// {
///   "status": 400,
///   "error": true,
///   "reason": "LOGIN.ERRORS.INVALID_CREDENTIALS",
///   "requestInfo": {
///     "description": "Login attempt"
///   },
///   "baseurl": "https://auth.example.com"
/// }
/// ```
///
/// ## Usage
///
/// ```swift
/// // Creating an error response
/// let error = ResponseError(
///     status: 400,
///     error: true,
///     reason: "LOGIN.ERRORS.INVALID_CREDENTIALS",
///     requestInfo: req.requestInfo
/// )
///
/// // Encoding as JSON
/// return try await req.view.render("error", error)
/// ```
///
/// ## Localization
///
/// The `reason` field typically contains a translation key (e.g., "LOGIN.ERRORS.NO_TENANT")
/// that can be localized in the frontend template.
///
/// ## Topics
///
/// ### Properties
/// - ``status``
/// - ``error``
/// - ``reason``
/// - ``requestInfo``
/// - ``baseurl``
///
/// ### Initialization
/// - ``init(status:error:reason:requestInfo:baseurl:)``
///
/// - SeeAlso: ``RequestInfo``
struct ResponseError: Codable, Sendable {
    /// The HTTP status code for the error.
    ///
    /// Examples: 400 (Bad Request), 401 (Unauthorized), 403 (Forbidden), 500 (Internal Server Error)
    let status: Int?

    /// Indicates whether an error occurred.
    ///
    /// - `true`: An error occurred
    /// - `false`: Special case where no error occurred (used for informational responses)
    let error: Bool

    /// A description or translation key explaining why the error occurred.
    ///
    /// This typically contains a translation key like "LOGIN.ERRORS.NO_TENANT" that can
    /// be localized in the frontend. For informational responses (`error: false`), this
    /// explains why the expected error did not occur.
    let reason: String

    /// Contextual information about the request that failed.
    ///
    /// Provides additional context for debugging or displaying helpful error messages.
    let requestInfo: RequestInfo?

    /// The base URL of the Uitsmijter authorization server.
    ///
    /// Used for constructing asset URLs and links in error pages.
    var baseurl: String

    /// Creates a new response error.
    ///
    /// - Parameters:
    ///   - status: The HTTP status code
    ///   - error: Whether this represents an error condition
    ///   - reason: The error reason or translation key
    ///   - requestInfo: Additional request context
    ///   - baseurl: The authorization server base URL (defaults to "localhost:8080")
    init(
        status: Int?, error: Bool, reason: String, requestInfo: RequestInfo?, baseurl: String = "localhost:8080"
    ) {
        self.status = status
        self.error = error
        self.reason = reason
        self.requestInfo = requestInfo
        self.baseurl = baseurl
    }
}
