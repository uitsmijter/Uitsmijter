import Foundation

/// Credentials that passes over into the javascript context
///
struct JSInputCredentials: JSInputParameterProtocol, Sendable {
    /// Users username or email address
    public let username: String
    /// Users password
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}
