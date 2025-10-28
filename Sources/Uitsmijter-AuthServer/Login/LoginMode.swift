import Foundation

// MARK: - Login Mode

/// Defines the authentication mode for incoming requests.
///
/// Uitsmijter supports two distinct authentication modes that determine how
/// users are authenticated and how requests are processed.
///
/// ## Modes
///
/// ### OAuth Mode
///
/// Standard OAuth2 authorization code flow where:
/// - Users are redirected to the authorization server
/// - Login forms are presented on the authorization server
/// - Authorization codes are exchanged for access tokens
/// - Tokens are returned to the client application
///
/// ### Interceptor Mode
///
/// Traefik ForwardAuth middleware integration where:
/// - All requests pass through Uitsmijter for authentication
/// - Users are transparently authenticated via cookies
/// - Failed authentication redirects to login
/// - Successful authentication forwards to the protected resource
///
/// ## Usage
///
/// ```swift
/// let mode = LoginMode(rawValue: "oauth") ?? .oauth
///
/// switch mode {
/// case .oauth:
///     // Handle OAuth flow
/// case .interceptor:
///     // Handle ForwardAuth middleware
/// }
/// ```
///
/// ## Mode Detection
///
/// The mode is determined by ``RequestClientMiddleware`` based on:
/// - `X-Uitsmijter-Mode` header
/// - `mode` query parameter
/// - Request route (`/interceptor`)
///
/// ## Topics
///
/// ### Cases
/// - ``interceptor``
/// - ``oauth``
///
/// - SeeAlso: ``RequestClientMiddleware``
/// - SeeAlso: ``ClientInfo``
enum LoginMode: String, Codable, Sendable {
    /// Traefik ForwardAuth middleware mode for transparent authentication.
    case interceptor

    /// Standard OAuth2 authorization code flow mode.
    case oauth
}
