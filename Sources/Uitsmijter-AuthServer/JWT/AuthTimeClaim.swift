import Foundation
@preconcurrency import JWT

/// Custom JWT claim representing the time of user authentication.
///
/// The "auth_time" claim is defined in OpenID Connect Core 1.0 Section 2 as the time when
/// the End-User authentication occurred. This is used to determine the freshness of
/// authentication and can be used to force re-authentication if needed.
///
/// ## OpenID Connect Specification
///
/// From [OIDC Core Section 2](https://openid.net/specs/openid-connect-core-1_0.html#IDToken):
/// > auth_time: Time when the End-User authentication occurred. Its value is a JSON number
/// > representing the number of seconds from 1970-01-01T00:00:00Z as measured in UTC until
/// > the date/time. When a max_age request is made or when auth_time is requested as an
/// > Essential Claim, then this Claim is REQUIRED; otherwise, its inclusion is OPTIONAL.
///
/// ## Usage
///
/// ```swift
/// let authTime = AuthTimeClaim(value: Date())
///
/// let payload = Payload(
///     // ... other claims ...
///     authTime: authTime
/// )
/// ```
///
/// ## Encoding Format
///
/// The claim is encoded as a Unix timestamp (seconds since epoch), consistent with other
/// time-based JWT claims like `exp` and `iat`.
///
/// - SeeAlso: ``Payload``
/// - SeeAlso: [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
struct AuthTimeClaim: JWTUnixEpochClaim, Equatable, Sendable {
    /// The claim's key in the JWT payload
    static let key: String = "auth_time"

    /// The authentication time as a Date
    var value: Date
}
