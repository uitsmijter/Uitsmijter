import Foundation
import Vapor

/// If the current requesting user is not logged in a login form is provided by the authorisation server. This model
/// holds the user typed in information.
///
/// - Parameters:
///     - username: The users username or email address
///     - password: The users password
///     - location: URL to redirect the user to after a login
public struct LoginForm: Content, Sendable {
    /// The users username or email address that is used as a _username_
    public let username: String

    /// The cleartext password of the user that will checked against the backend user storage
    public let password: String

    /// A location where the user will be redirected after the login proceeds.
    /// The `location` must match one of the `Client``s `redirect_urls`.
    /// - SeeAlso:
    ///     - Client
    ///     - redirect_urls
    public let location: String

    /// Optional request scopes
    public let scope: String?

    public init(username: String, password: String, location: String, scope: String? = nil) {
        self.username = username
        self.password = password
        self.location = location
        self.scope = scope
    }
}
