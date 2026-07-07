import Foundation

/// Credentials that passes over into the javascript context
///
struct JSInputCredentials: JSInputParameterProtocol, Sendable {
    /// Users username or email address
    let username: String
    /// Users password
    let password: String
    /// The OAuth2 grant type used for this authentication request
    let grantType: GrantTypes
    /// The tenant this authentication request belongs to
    let tenant: JSInputTenant

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case grantType = "grant_type"
        case tenant
    }
}
