import Foundation
import Vapor

public struct TokenResponse: Content, Sendable {
    /// The access token string as issued by the authorization server.
    public let access_token: String

    /// The type of token this is, typically just the string "Bearer".
    public let token_type: TokenTypes

    /// If the access token expires, the server should reply with the duration of time the access token is granted for.
    public let expires_in: Int?

    /// If the access token will expire, then it is useful to return a refresh token which applications can use to
    /// obtain another access token.
    /// However, tokens issued with the implicit grant should not be issued a refresh token.
    public let refresh_token: String?

    /// if the scope the user granted is identical to the scope the app requested, this parameter is optional. If the
    /// granted scope is different from the requested scope, such as if the user modified the scope, then this parameter
    /// is required.
    public let scope: String?

    public init(
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
