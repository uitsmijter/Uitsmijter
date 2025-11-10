import Vapor

/// OAuth 2.0 Token Revocation Request (RFC 7009)
///
/// Represents a token revocation request as specified in
/// [RFC 7009: OAuth 2.0 Token Revocation](https://datatracker.ietf.org/doc/html/rfc7009).
///
/// The revocation endpoint allows clients to notify the authorization server that
/// a previously obtained token (access token or refresh token) is no longer needed
/// and should be invalidated.
///
/// ## Example Request
///
/// ```http
/// POST /revoke HTTP/1.1
/// Host: auth.example.com
/// Content-Type: application/x-www-form-urlencoded
///
/// token=V7vZQbJNNY7zR8IWyV7vZQbJNNY7zR8IW
/// &token_type_hint=access_token
/// &client_id=9095A4F2-35B2-48B1-A325-309CA324B97E
/// &client_secret=secret123
/// ```
///
/// - SeeAlso: [RFC 7009](https://datatracker.ietf.org/doc/html/rfc7009)
struct RevokeRequest: Content {

    /// REQUIRED. The token that the client wants to get revoked.
    ///
    /// This can be either an access token or a refresh token.
    let token: String

    /// OPTIONAL. A hint about the type of the token submitted for revocation.
    ///
    /// Clients MAY pass this parameter to help the authorization server
    /// optimize the token lookup. If the server is unable to locate the
    /// token using the given hint, it MUST extend its search across all
    /// of its supported token types.
    ///
    /// Possible values:
    /// - `"access_token"` - The token is an access token
    /// - `"refresh_token"` - The token is a refresh token
    ///
    /// Invalid values are ignored and do not cause an error.
    let token_type_hint: String?

    /// REQUIRED. The client identifier as described in RFC 6749, Section 2.2.
    ///
    /// This is the unique identifier of the client application that is
    /// requesting the token revocation.
    let client_id: String

    /// OPTIONAL/REQUIRED. The client secret.
    ///
    /// This parameter is REQUIRED for confidential clients (clients with a secret).
    /// Public clients (without a secret) MUST NOT include this parameter.
    ///
    /// The authorization server MUST validate the client credentials as
    /// described in RFC 6749, Section 3.2.1.
    let client_secret: String?
}
