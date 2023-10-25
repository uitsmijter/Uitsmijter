import Foundation

/// Information stored in the session between login and authorize.
///
/// - Parameter:
///     - state: A string send by the client
///     - code:  An intermediary token generated when a user authorizes a client
///     - scopes: The requested scopes to get permissions for
///     - redirect: An URL where the response should be delegated to
struct LoginSession: Codable, TimeToLiveProtocol {

    /// A individual UUID per login
    let loginId: UUID

    /// Time To Live for that the login is valid
    var ttl: Int64? = 2 * 60

    /// Timestamp when this session was generated
    var generated: Date = Date()

    init(loginId: UUID) {
        self.loginId = loginId
    }
}
