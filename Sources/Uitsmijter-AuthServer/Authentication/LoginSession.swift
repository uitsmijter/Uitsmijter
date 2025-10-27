import Foundation

/// Session state between user login and OAuth2 authorization.
///
/// `LoginSession` bridges the gap between when a user successfully authenticates
/// and when they authorize an OAuth2 client. This temporary session ensures that
/// the authorization request can be correlated with the authenticated user.
///
/// ## Login Flow
///
/// 1. Client initiates OAuth2 authorization request
/// 2. User is redirected to login page
/// 3. User submits credentials
/// 4. Upon successful authentication, `LoginSession` is created
/// 5. User is shown authorization consent screen
/// 6. Upon consent, login session is consumed and `AuthSession` is created
///
/// ## Session Lifecycle
///
/// Login sessions are short-lived (default 2 minutes) to minimize the window
/// for potential attacks. After the TTL expires, the user must re-authenticate.
///
/// ## Example
///
/// ```swift
/// let session = LoginSession(loginId: UUID())
/// // Session expires after 2 minutes (120 seconds)
/// ```
///
/// ## Security Considerations
///
/// - Login sessions have short TTLs to prevent session hijacking
/// - Each login gets a unique UUID to prevent correlation attacks
/// - Sessions are stored securely in Redis or memory
/// - Sessions are single-use and consumed during authorization
///
/// - SeeAlso: ``AuthSession``, ``TimeToLiveProtocol``
public struct LoginSession: Codable, TimeToLiveProtocol, Sendable {

    /// A unique identifier for this login attempt.
    ///
    /// This UUID correlates the login with the subsequent authorization,
    /// ensuring that only the authenticated user can authorize clients.
    public let loginId: UUID

    /// Time-to-live for this login session in seconds.
    ///
    /// Defaults to 120 seconds (2 minutes). After expiration, the user
    /// must re-authenticate before authorizing clients.
    public var ttl: Int64? = 2 * 60

    /// The timestamp when this login session was created.
    ///
    /// Used for session expiration calculations and auditing.
    public var generated: Date = Date()

    /// Initialize a login session.
    ///
    /// - Parameter loginId: A unique identifier for this login attempt
    public init(loginId: UUID) {
        self.loginId = loginId
    }
}
