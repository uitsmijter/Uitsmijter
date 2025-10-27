import Foundation

/// The authentication server supports several grant types for different use cases
public enum GrantTypes: String, Codable, Sendable {

    /// The Authorization Code grant type is used by confidential and public clients to exchange an authorization code
    /// for an access token.
    /// After the user returns to the client via the redirect URL, the application will get the authorization code from
    /// the URL and use it to request an access token.
    ///
    /// - Note: It is recommended that all clients use the PKCE extension with this flow as well to provide better
    ///         security.
    case authorization_code

    /// The Refresh Token grant type is used by clients to exchange a refresh token for an access token when the access
    /// token has expired.
    /// This allows clients to continue to have a valid access token without further interaction with the user.
    case refresh_token

    /// The Password grant type is a way to exchange a user's credentials for an access token. Because the client
    /// application has to collect the user's password and send it to the authorization server, it is not recommended
    /// that this grant be used at all anymore.
    /// This flow provides no mechanism for things like multifactorial authentication or delegated accounts, so is quite
    /// limiting in practice.
    ///
    /// - Note:
    ///     - The latest OAuth 2.0 Security
    ///       [Best Current Practice](https://tools.ietf.org/html/draft-ietf-oauth-security-topics-13#section-3.4)
    ///       disallows the password grant entirely.
    ///
    /// - Attention: password is disabled by default. Clients has to be opt-in
    case password

    /// A special grant type that Uitsmijter supports for an authentication middleware that passes the user to
    /// a backend system if the login succeeds.
    case interceptor
}
