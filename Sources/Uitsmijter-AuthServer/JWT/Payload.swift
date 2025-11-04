import Foundation
@preconcurrency import JWT

/// JWT payload structure for successful authorization requests
///
/// Contains all claims and custom data included in JWT access tokens issued by the authorization server.
/// Conforms to `JWTPayload` for JWT encoding/decoding, `SubjectProtocol` for subject identification,
/// and `UserProfileProtocol` for user profile information.
///
/// ## Standard JWT Claims
///
/// Includes the following registered JWT claims per [RFC 7519](https://tools.ietf.org/html/rfc7519):
/// - `iss` (Issuer): Identifies the principal that issued the JWT
/// - `sub` (Subject): Identifies the principal that is the subject of the JWT
/// - `aud` (Audience): Identifies the recipients that the JWT is intended for
/// - `exp` (Expiration Time): Expiration time on or after which the JWT must not be accepted
/// - `iat` (Issued At): Time at which the JWT was issued
///
/// ## OpenID Connect Claims
///
/// Includes the following OpenID Connect claims per [OIDC Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html):
/// - `auth_time`: Time when the End-User authentication occurred
///
/// - SeeAlso: ``Token``
/// - SeeAlso: ``AuthTimeClaim``
struct Payload: JWTPayload, SubjectProtocol, UserProfileProtocol, Sendable {

    /// Maps Swift property names to JWT claim keys
    ///
    /// Defines the encoding/decoding keys for JWT payload fields, using standard JWT claim names
    /// where applicable (e.g., "sub" for subject, "exp" for expiration).
    enum CodingKeys: String, CodingKey {
        case issuer = "iss"
        case subject = "sub"
        case audience = "aud"
        case expiration = "exp"
        case issuedAt = "iat"
        case authTime = "auth_time"
        case tenant = "tenant"
        case responsibility = "responsibility"
        case role = "role"
        case user = "user"
        case profile = "profile"
    }

    // MARK: - Standard JWT Claims

    /// The issuer claim
    ///
    /// The "iss" (issuer) claim identifies the principal that issued the JWT.
    /// Typically the authorization server's URL.
    var issuer: IssuerClaim

    /// The subject claim identifying the principal
    ///
    /// The "sub" (subject) claim identifies the principal that is the subject of the JWT,
    /// typically the authenticated user identifier.
    var subject: SubjectClaim

    /// The audience claim
    ///
    /// The "aud" (audience) claim identifies the recipients that the JWT is intended for.
    /// Typically the client_id of the OAuth2 client that requested the token.
    var audience: AudienceClaim

    /// The expiration time claim
    ///
    /// The "exp" (expiration time) claim identifies the expiration time on or after which
    /// the JWT must not be accepted for processing.
    var expiration: ExpirationClaim

    /// The issued-at time claim
    ///
    /// The "iat" (issued at) claim identifies the time at which the JWT was issued.
    /// Used to determine the age of the JWT.
    var issuedAt: IssuedAtClaim

    /// The authentication time claim
    ///
    /// The "auth_time" claim from OpenID Connect identifies when the End-User authentication occurred.
    /// Used to determine if re-authentication is needed based on max_age or other policies.
    var authTime: AuthTimeClaim

    // MARK: - Custom data

    /// The tenant for which the payload is valid
    ///
    /// Identifies the tenant context for this token, enabling multi-tenant authorization.
    var tenant: String

    /// Hash for responsibility domain verification
    ///
    /// Optional hash used to verify the responsibility domain, ensuring the token
    /// is used within the correct authorization scope.
    var responsibility: String?

    /// The user's role within the system
    ///
    /// Used for role-based access control (RBAC) decisions.
    var role: String

    /// The username or identifier of the user
    ///
    /// The authenticated user's username, typically an email address.
    var user: String

    /// Additional user profile data
    ///
    /// Optional untyped profile information containing custom user attributes.
    var profile: CodableProfile?

    /// Creates a new JWT payload
    ///
    /// - Parameters:
    ///   - issuer: The issuer claim (authorization server URL)
    ///   - subject: The subject claim identifying the user
    ///   - audience: The audience claim (client_id)
    ///   - expiration: The expiration time claim
    ///   - issuedAt: The issued-at time claim
    ///   - authTime: The authentication time claim
    ///   - tenant: The tenant name for multi-tenant context
    ///   - responsibility: Optional responsibility domain hash
    ///   - role: The user's role for authorization
    ///   - user: The username or identifier
    ///   - profile: Optional additional profile data
    init(
        issuer: IssuerClaim,
        subject: SubjectClaim,
        audience: AudienceClaim,
        expiration: ExpirationClaim,
        issuedAt: IssuedAtClaim,
        authTime: AuthTimeClaim,
        tenant: String,
        responsibility: String? = nil,
        role: String,
        user: String,
        profile: CodableProfile? = nil
    ) {
        self.issuer = issuer
        self.subject = subject
        self.audience = audience
        self.expiration = expiration
        self.issuedAt = issuedAt
        self.authTime = authTime
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
    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}
