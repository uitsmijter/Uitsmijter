import Foundation

/// Credentials that passes over into the javascript context
///
struct JSInputCredentials: JSInputParameterProtocol, Sendable {
    /// Users username or email address
    let username: String
    /// Users password
    let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}
