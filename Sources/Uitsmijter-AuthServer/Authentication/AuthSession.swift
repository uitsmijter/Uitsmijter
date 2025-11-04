import Foundation

/// Session state for OAuth2 authorization code flow.
///
/// `AuthSession` stores the intermediate state during an OAuth2 authorization flow,
/// bridging the gap between user authorization and token exchange. This session
/// contains the authorization code, state parameter, and user payload that will
/// be used to generate access tokens.
///
/// ## OAuth2 Authorization Code Flow
///
/// 1. Client initiates authorization request with `state` parameter
/// 2. User authenticates and authorizes the client
/// 3. `AuthSession` is created with authorization `code` and user `payload`
/// 4. Session is stored temporarily (with TTL)
/// 5. Client exchanges code for access token at token endpoint
/// 6. Session is consumed and removed
///
/// ## Session Types
///
/// Auth sessions can represent different OAuth2 flows:
/// - ``CodeType/code``: Standard authorization code
/// - ``CodeType/refresh``: Refresh token flow
///
/// ## Example
///
/// ```swift
/// let session = AuthSession(
///     type: .code,
///     state: "xyz123",
///     code: Code(),
///     scopes: ["openid", "profile"],
///     payload: userPayload,
///     redirect: "https://app.example.com/callback",
///     ttl: 300  // 5 minutes
/// )
/// ```
///
/// ## Security Considerations
///
/// - Authorization codes are single-use and expire quickly (typically 5-10 minutes)
/// - The `state` parameter prevents CSRF attacks (RFC 6749, Section 10.12)
/// - Sessions are stored securely in Redis or memory
/// - Codes should be cryptographically random
///
/// - SeeAlso: ``Code``, ``Payload``, ``TimeToLiveProtocol``
struct AuthSession: Codable, TimeToLiveProtocol, Sendable {
    /// The type of authorization code.
    ///
    /// Distinguishes between standard authorization codes and refresh tokens.
    enum CodeType: String, Codable, Sendable {
        /// Standard authorization code from authorization endpoint.
        case code

        /// Refresh token used to obtain new access tokens.
        case refresh
    }

    /// The type of this authorization session.
    ///
    /// Specifies whether this is a standard authorization code or refresh token session.
    let type: AuthSession.CodeType

    /// The state parameter from the client's authorization request.
    ///
    /// This opaque value is returned unchanged to the client to prevent CSRF attacks.
    /// The client should verify this matches their original request.
    ///
    /// Per OAuth 2.0 (RFC 6749, Section 10.12), the state parameter is recommended
    /// for preventing cross-site request forgery.
    let state: String

    /// The authorization code generated for this session.
    ///
    /// This one-time code is exchanged for an access token at the token endpoint.
    /// The code is cryptographically random and expires quickly (typically 5-10 minutes).
    ///
    /// - SeeAlso: ``Code``
    let code: Code

    /// The OAuth2 scopes approved for this authorization.
    ///
    /// Contains the intersection of:
    /// - Scopes requested by the client
    /// - Scopes allowed for the client
    /// - Scopes authorized by the user
    ///
    /// These scopes determine the permissions granted to the resulting access token.
    let scopes: [String]

    /// The authenticated user's payload.
    ///
    /// Contains user information retrieved from the authentication provider.
    /// This payload is used to populate claims in the issued JWT access token.
    ///
    /// - SeeAlso: ``Payload``
    let payload: Payload?

    /// The redirect URI where the authorization response will be sent.
    ///
    /// This URI must match one of the client's registered redirect URIs.
    /// After authorization, the authorization code is sent to this URI.
    let redirect: String

    /// Time-to-live for this session in seconds.
    ///
    /// Authorization codes should have short lifetimes (typically 300-600 seconds).
    /// After expiration, the session is automatically removed from storage.
    ///
    /// Per OAuth 2.0 (RFC 6749, Section 4.1.2), authorization codes should be
    /// short-lived and single-use.
    var ttl: Int64?

    /// The timestamp when this session was created.
    ///
    /// Used for session expiration calculations and auditing.
    var generated: Date = Date()

    /// Initialize an authorization session.
    ///
    /// - Parameters:
    ///   - type: The type of authorization code (code or refresh)
    ///   - state: The state parameter from the authorization request
    ///   - code: The generated authorization code
    ///   - scopes: The approved OAuth2 scopes
    ///   - payload: The authenticated user's payload
    ///   - redirect: The redirect URI for the authorization response
    ///   - ttl: Optional time-to-live in seconds (defaults to system configuration)
    ///   - generated: The session creation timestamp (defaults to now)
    init(
        type: AuthSession.CodeType, state: String, code: Code, scopes: [String],
        payload: Payload?, redirect: String, ttl: Int64? = nil, generated: Date = Date()
    ) {
        self.type = type
        self.state = state
        self.code = code
        self.scopes = scopes
        self.payload = payload
        self.redirect = redirect
        self.ttl = ttl
        self.generated = generated
    }

}
