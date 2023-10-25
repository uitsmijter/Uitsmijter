import Foundation
import Vapor

struct TokenResponse: Codable {
    /// The access token string as issued by the authorization server.
    let access_token: String

    /// The type of token this is, typically just the string “Bearer”.
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
}

extension TokenResponse: Content {

}
