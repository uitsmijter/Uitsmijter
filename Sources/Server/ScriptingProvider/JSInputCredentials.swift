import Foundation

/// Credentials that passes over into the javascript context
///
struct JSInputCredentials: JSInputParameterProtocol {
    /// Users username or email address
    let username: String
    /// Users password
    let password: String
}
