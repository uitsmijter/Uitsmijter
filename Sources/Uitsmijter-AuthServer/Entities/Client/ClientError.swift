import Foundation

/// Errors that can occur during client validation and operation.
///
/// These errors are thrown when client configuration or request validation fails,
/// typically during OAuth2 authorization flows.
enum ClientError: Error {
    /// The client is not properly associated with a tenant.
    ///
    /// All clients must belong to a tenant. This error occurs when attempting
    /// to use a client that has no tenant association.
    case clientHasNoTenant

    /// The requested redirect URI does not match the client's allowed patterns.
    ///
    /// Per OAuth 2.0 security best practices (RFC 6749), redirect URIs must be
    /// pre-registered and validated to prevent authorization code interception attacks.
    ///
    /// - Parameters:
    ///   - redirect: The redirect URI that was rejected
    ///   - reason: A localization key explaining the rejection reason
    case illegalRedirect(redirect: String, reason: String = "LOGIN.ERRORS.REDIRECT_MISMATCH")

    /// The request referer does not match the client's allowed referers.
    ///
    /// This provides additional security by validating that requests originate
    /// from expected domains.
    ///
    /// - Parameters:
    ///   - referer: The referer that was rejected
    ///   - reason: A localization key explaining the rejection reason
    case illegalReferer(referer: String, reason: String = "LOGIN.ERRORS.WRONG_REFERER")
}
