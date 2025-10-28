import Foundation

/// Credentials that passes over into the javascript context
///
struct JSInputUsername: JSInputParameterProtocol, Sendable {
    /// Users username or email address
    public let username: String

    public init(username: String) {
        self.username = username
    }
}
