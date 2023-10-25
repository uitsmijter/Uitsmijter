import Foundation
import Vapor

/// If the current requesting user is not logged in a login form is provided by the authorisation server. This model
/// holds the user typed in information.
///
/// - Parameters:
///     - username: The users username or email address
///     - password: The users password
///     - location: URL to redirect the user to after a login
struct LoginForm: Codable {
    /// The users username or email address that is used as a _username_
    let username: String

    /// The cleartext password of the user that will checked against the backend user storage
    let password: String

    /// A location where the user will be redirected after the login proceeds.
    /// The `location` must match one of the `Client``s `redirect_urls`.
    /// - SeeAlso:
    ///     - Client
    ///     - redirect_urls
    let location: String

    /// Optional request scopes
    let scope: String?
}

extension LoginForm {
    /// Initialize a new LoginForm without scopes
    ///
    /// - Parameters:
    ///   - username: The users username or email address that is used as a _username_
    ///   - password: The cleartext password of the user that will checked against the backend user storage
    ///   - location: A location where the user will be redirected after the login proceeds.
    init(
            username: String,
            password: String,
            location: String
    ) {
        self.username = username
        self.password = password
        self.location = location
        scope = ""
    }

    /// Initialize a new LoginForm without scopes
    ///
    /// - Parameters:
    ///   - username: The users username or email address that is used as a _username_
    ///   - password: The cleartext password of the user that will checked against the backend user storage
    ///   - location: A location where the user will be redirected after the login proceeds.
    ///   - scopes: Allowed selected scopes as comma seperated string
    init(
            username: String,
            password: String,
            location: String,
            scopes: String?
    ) {
        self.username = username
        self.password = password
        self.location = location
        scope = scopes ?? ""
    }
}

/// Extends the `LoginForm` that it can be used as a [Vapor content](https://docs.vapor.codes/basics/content/) object
extension LoginForm: Content {
}
