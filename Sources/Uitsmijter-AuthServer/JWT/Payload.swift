import Foundation
@preconcurrency import JWT

/// JWT payload structure for successful authorization requests
///
/// Contains all claims and custom data included in JWT access tokens issued by the authorization server.
/// Conforms to `JWTPayload` for JWT encoding/decoding, `SubjectProtocol` for subject identification,
/// and `UserProfileProtocol` for user profile information.
public struct Payload: JWTPayload, SubjectProtocol, UserProfileProtocol, Sendable {

    /// Maps Swift property names to JWT claim keys
    ///
    /// Defines the encoding/decoding keys for JWT payload fields, using standard JWT claim names
    /// where applicable (e.g., "sub" for subject, "exp" for expiration).
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case tenant = "tenant"
        case responsibility = "responsibility"
        case role = "role"
        case user = "user"
        case profile = "profile"
    }

    /// The subject claim identifying the principal
    ///
    /// The "sub" (subject) claim identifies the principal that is the subject of the JWT,
    /// typically the authenticated user identifier.
    public var subject: SubjectClaim

    /// The expiration time claim
    ///
    /// The "exp" (expiration time) claim identifies the expiration time on or after which
    /// the JWT must not be accepted for processing.
    public var expiration: ExpirationClaim

    // MARK: - Custom data

    /// The tenant for which the payload is valid
    ///
    /// Identifies the tenant context for this token, enabling multi-tenant authorization.
    public var tenant: String

    /// Hash for responsibility domain verification
    ///
    /// Optional hash used to verify the responsibility domain, ensuring the token
    /// is used within the correct authorization scope.
    public var responsibility: String?

    /// The user's role within the system
    ///
    /// Used for role-based access control (RBAC) decisions.
    public var role: String

    /// The username or identifier of the user
    ///
    /// The authenticated user's username, typically an email address.
    public var user: String

    /// Additional user profile data
    ///
    /// Optional untyped profile information containing custom user attributes.
    public var profile: CodableProfile?

    /// Creates a new JWT payload
    ///
    /// - Parameters:
    ///   - subject: The subject claim identifying the user
    ///   - expiration: The expiration time claim
    ///   - tenant: The tenant name for multi-tenant context
    ///   - responsibility: Optional responsibility domain hash
    ///   - role: The user's role for authorization
    ///   - user: The username or identifier
    ///   - profile: Optional additional profile data
    public init(
        subject: SubjectClaim, expiration: ExpirationClaim, tenant: String, responsibility: String? = nil,
        role: String, user: String, profile: CodableProfile? = nil
    ) {
        self.subject = subject
        self.expiration = expiration
        self.tenant = tenant
        self.responsibility = responsibility
        self.role = role
        self.user = user
        self.profile = profile
    }

    // MARK: - JWTPayload

    /// Verifies that the token has not expired
    ///
    /// Checks the expiration claim against the current date to ensure the token is still valid.
    ///
    /// - Parameter signer: The JWT signer to use for verification (unused, but required by protocol)
    /// - Throws: `JWTError.claimVerificationFailure` if the token has expired
    public func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}
