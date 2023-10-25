import Foundation

/// Information stored in the session between two setups auf the OAuth flow.
///
/// - Parameter:
///     - state: A string send by the client
///     - code:  An intermediary token generated when a user authorizes a client
///     - scopes: The requested scopes to get permissions for
///     - redirect: An URL where the response should be delegated to
struct AuthSession: Codable, TimeToLiveProtocol {
    enum CodeType: String, Codable {
        case code
        case refresh
    }

    /// AuthSessions can have different types that must be specified
    let type: AuthSession.CodeType

    /// A string send by the client that will be unchanged sends back in the respond
    let state: String

    /// An intermediary token generated when a user authorizes a client to access protected resources on their behalf.
    /// The client receives this token and exchanges it for an access token.
    /// - Defaults:
    ///     - A random String with a length of 16
    /// - SeeAlso: Code
    ///
    /// The value can be overwritten while initialising a `AuthSession`.
    let code: Code

    /// The requested scopes to get permissions for, reduced by the scopes that are valid for the client
    let scopes: [String]

    /// The users login Payload
    let payload: Payload?

    /// An URL where the response should be delegated to after authorisation is given
    let redirect: String

    /// Optional Time To Live for the Session
    var ttl: Int64?

    /// Timestamp when this session was generated
    var generated: Date = Date()

}
