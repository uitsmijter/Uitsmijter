import Foundation

/// Credentials that passes over into the javascript context
///
struct JSInputUsername: JSInputParameterProtocol, Sendable {
    /// Users username or email address
    let username: String
    /// The tenant this validation request belongs to
    let tenant: JSInputTenant
}
