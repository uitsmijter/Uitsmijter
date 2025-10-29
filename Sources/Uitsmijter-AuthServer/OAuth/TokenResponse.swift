import Foundation
import Vapor

/// OAuth2 token endpoint response structure.
///
/// Represents the successful response from the token endpoint as defined in
/// RFC 6749, Section 5.1. This response contains the access token and related
/// metadata that the client will use to access protected resources.
///
/// ## Response Fields
///
/// - `access_token`: The issued access token (typically a JWT)
/// - `token_type`: The type of token, usually "Bearer"
/// - `expires_in`: Token lifetime in seconds
/// - `refresh_token`: Optional refresh token for obtaining new access tokens
/// - `scope`: The approved scopes if different from requested
///
/// ## Example Response
///
/// ```json
/// {
///   "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
///   "token_type": "Bearer",
///   "expires_in": 3600,
///   "refresh_token": "def50200...",
///   "scope": "openid profile email"
/// }
/// ```
///
/// - SeeAlso: RFC 6749, Section 5.1 (Successful Response)
struct TokenResponse: Content, Sendable {
    /// The access token string as issued by the authorization server.
    let access_token: String

    /// The type of token this is, typically just the string "Bearer".
    let token_type: TokenTypes

    /// If the access token expires, the server should reply with the duration of time the access token is granted for.
    let expires_in: Int?

    /// If the access token will expire, then it is useful to return a refresh token which applications can use to
    /// obtain another access token.
    /// However, tokens issued with the implicit grant should not be issued a refresh token.
    let refresh_token: String?

    /// if the scope the user granted is identical to the scope the app requested, this parameter is optional. If the
    /// granted scope is different from the requested scope, such as if the user modified the scope, then this parameter
    /// is required.
    let scope: String?

    init(
        access_token: String, token_type: TokenTypes, expires_in: Int? = nil,
        refresh_token: String? = nil, scope: String? = nil
    ) {
        self.access_token = access_token
        self.token_type = token_type
        self.expires_in = expires_in
        self.refresh_token = refresh_token
        self.scope = scope
    }
}
