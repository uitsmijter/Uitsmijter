import Foundation

/// Credentials that passes over into the javascript context
///
struct JSInputUsername: JSInputParameterProtocol {
    /// Users username or email address
    let username: String
}
