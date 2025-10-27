import Foundation
import Vapor

// MARK: - Client Info Request

/// Represents the original HTTP request details before forwarding.
///
/// This structure captures the essential components of an HTTP request
/// that may have been proxied through Traefik or other reverse proxies.
///
/// ## Topics
///
/// ### Properties
/// - ``scheme``
/// - ``host``
/// - ``uri``
/// - ``description``
public struct ClientInfoRequest: Codable {
    /// The HTTP scheme (http or https).
    let scheme: String

    /// The target hostname.
    let host: String

    /// The request URI path.
    let uri: String

    /// A formatted string representation of the full URL.
    ///
    /// Combines scheme, host, and URI into a complete URL string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let request = ClientInfoRequest(scheme: "https", host: "app.example.com", uri: "/api/data")
    /// print(request.description) // "https://app.example.com/api/data"
    /// ```
    var description: String {
        get {
            "\(scheme)://\(host)\(uri)"
        }
    }
}

// MARK: - Client Info

/// Comprehensive client, tenant, and authentication information for a request.
///
/// This structure aggregates all relevant information about the requesting client,
/// including authentication mode, tenant association, JWT validation status, and
/// the original request details.
///
/// ## Usage
///
/// ``ClientInfo`` is attached to Vapor requests via the ``Request/clientInfo``
/// property by ``RequestClientMiddleware``.
///
/// ```swift
/// func handler(req: Request) throws -> Response {
///     guard let clientInfo = req.clientInfo else {
///         throw Abort(.badRequest)
///     }
///
///     let tenant = clientInfo.tenant
///     let mode = clientInfo.mode
///     // ...
/// }
/// ```
///
/// ## Authentication State
///
/// - ``validPayload``: Present if user has a valid JWT token
/// - ``expired``: Indicates if the JWT token is expired
/// - ``subject``: User identifier from the JWT
///
/// ## Topics
///
/// ### Login Mode
/// - ``mode``
///
/// ### Request Information
/// - ``requested``
/// - ``referer``
/// - ``responsibleDomain``
/// - ``serviceUrl``
///
/// ### Client and Tenant
/// - ``tenant``
/// - ``client``
///
/// ### Authentication Status
/// - ``expired``
/// - ``subject``
/// - ``validPayload``
/// - ``isExpired()``
///
/// - SeeAlso: ``LoginMode``
/// - SeeAlso: ``RequestClientMiddleware``
public struct ClientInfo: Codable, @unchecked Sendable {
    /// The login mode (OAuth or Interceptor).
    let mode: LoginMode

    /// The original request details.
    let requested: ClientInfoRequest

    /// The HTTP referer header value, if present.
    let referer: String?

    /// The domain responsible for handling this request.
    let responsibleDomain: String

    /// The service URL of the authorization server.
    let serviceUrl: String

    /// The associated tenant, if resolved.
    var tenant: Tenant?

    /// The associated OAuth client, if resolved.
    var client: UitsmijterClient?

    /// Indicates if the JWT token is expired.
    var expired: Bool?

    /// The user identifier from the JWT token.
    var subject: String?

    /// The validated JWT payload, if token is valid.
    var validPayload: Payload?

    /// Checks if the authentication token is expired.
    ///
    /// - Returns: `true` if the token is expired or not present, `false` if valid
    func isExpired() -> Bool {
        expired ?? true
    }
}

// MARK: - Storage Key

/// Storage key for accessing ``ClientInfo`` in Vapor's request storage.
struct ClientInfoKey: StorageKey {
    typealias Value = ClientInfo
}

// MARK: - Request Extension

/// Extension to add client information to Vapor requests.
extension Request {
    /// The client information for this request.
    ///
    /// This property is populated by ``RequestClientMiddleware`` and contains
    /// comprehensive information about the client, tenant, and authentication state.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func protectedRoute(req: Request) throws -> Response {
    ///     guard let info = req.clientInfo,
    ///           let tenant = info.tenant else {
    ///         throw Abort(.unauthorized)
    ///     }
    ///
    ///     // Use tenant and client information
    ///     return try renderPage(for: tenant)
    /// }
    /// ```
    ///
    /// - SeeAlso: ``ClientInfo``
    /// - SeeAlso: ``RequestClientMiddleware``
    var clientInfo: ClientInfo? {
        get {
            storage[ClientInfoKey.self]
        }
        set {
            storage[ClientInfoKey.self] = newValue
        }
    }
}
