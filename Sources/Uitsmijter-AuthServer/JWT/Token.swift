import Foundation
import JWTKit
import Logger

/// JWT access token with embedded user payload and metadata.
///
/// `Token` represents a complete JWT (JSON Web Token) that encapsulates user authentication
/// and authorization information. It provides both creation and verification capabilities,
/// supporting the full token lifecycle in Uitsmijter's authentication system.
///
/// ## Token Structure
///
/// A Token contains:
/// - **Header**: Algorithm and token type (HS256, JWT)
/// - **Payload**: User claims (subject, expiration, tenant, role, profile)
/// - **Signature**: HMAC-SHA256 signature for verification
///
/// ## Creation Methods
///
/// Tokens can be created in two ways:
/// 1. **From String Literal**: Parse and verify an existing JWT string
/// 2. **From User Credentials**: Generate a new signed token for a user
///
/// ## Example Usage
///
/// ```swift
/// // Create a new token for a user
/// let token = try Token(
///     tenantName: "acme-corp",
///     subject: "user@example.com",
///     userProfile: userProfile
/// )
///
/// // Verify an existing token
/// let existingToken: Token = "eyJhbGciOiJIUzI1NiIs..."
/// if existingToken.secondsToExpire > 0 {
///     print("Token is valid for user: \(existingToken.payload.user)")
/// }
/// ```
///
/// ## Expiration
///
/// Token expiration is controlled by the `TOKEN_EXPIRATION_IN_HOURS` environment
/// variable (default: 2 hours). The `expirationDate` and `secondsToExpire` properties
/// provide easy expiration checking.
///
/// ## Security
///
/// Tokens are signed using HMAC-SHA256 (HS256) with a secret key from the
/// `JWT_SECRET` environment variable. Always verify tokens before trusting their contents.
///
/// - Note: This struct conforms to `ExpressibleByStringLiteral` for convenient initialization.
/// - SeeAlso: ``Payload`` for the token payload structure
/// - SeeAlso: ``jwt_signer`` for the signing mechanism
struct Token: ExpressibleByStringLiteral {

    typealias StringLiteralType = String

    /// JWT signers instance for signing and verifying tokens.
    ///
    /// This instance is configured with the global ``jwt_signer`` using HS256 algorithm.
    let signers = JWTSigners()

    /// The date and time when this token expires.
    ///
    /// After this date, the token is no longer valid and should not be accepted
    /// for authentication. Clients should request a new token before expiration.
    let expirationDate: Date

    /// Number of seconds remaining until the token expires.
    ///
    /// This value is calculated at token initialization time. For tokens created
    /// from string literals, it represents the time remaining from the moment of
    /// decoding. A value of 0 or negative indicates an expired token.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if token.secondsToExpire > 3600 {
    ///     // Token valid for more than 1 hour
    /// } else if token.secondsToExpire > 0 {
    ///     // Token valid but expiring soon
    /// } else {
    ///     // Token expired
    /// }
    /// ```
    let secondsToExpire: Int

    /// The decoded JWT payload containing user authentication and authorization data.
    ///
    /// The payload includes standard claims (sub, exp) and custom claims
    /// (tenant, role, user, profile). This data should be treated as trusted
    /// only after successful signature verification.
    ///
    /// - SeeAlso: ``Payload`` for payload structure details
    let payload: Payload

    /// The encoded JWT string value in the form "header.payload.signature".
    ///
    /// This is the complete JWT string that can be sent to clients or verified
    /// later. It includes the Base64URL-encoded header, payload, and HMAC signature.
    ///
    /// ## Example JWT Structure
    ///
    /// ```
    /// eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
    /// eyJzdWIiOiJ1c2VyQGV4YW1wbGUuY29tIiwiZXhwIjoxNjE2MjM5MDIyfQ.
    /// SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
    /// ```
    let value: String

    /// Initializes a token by verifying and decoding a JWT string.
    ///
    /// This initializer allows creating a `Token` instance from a JWT string literal,
    /// enabling convenient syntax like: `let token: Token = "eyJhbGc..."`. The string
    /// is verified using the configured signer, and the payload is extracted.
    ///
    /// ## Verification Process
    ///
    /// 1. Configures signers with the global HS256 signer
    /// 2. Verifies the signature matches the header and payload
    /// 3. Decodes the payload into a `Payload` struct
    /// 4. Extracts expiration date and calculates remaining time
    ///
    /// ## Error Handling
    ///
    /// If verification or decoding fails (due to invalid signature, malformed JWT,
    /// or decoding errors), this initializer creates an "error token" with:
    /// - Subject set to "ERROR"
    /// - Expiration date set to current time (immediately expired)
    /// - Empty tenant, role, and user fields
    /// - `secondsToExpire` set to 0
    ///
    /// The error is logged but not thrown, allowing the initialization to complete.
    /// Callers should check `secondsToExpire` or payload fields to detect invalid tokens.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let tokenString = "eyJhbGciOiJIUzI1NiIs..."
    /// let token: Token = tokenString
    ///
    /// if token.payload.subject.value == "ERROR" {
    ///     // Invalid or tampered token
    /// } else {
    ///     // Valid token, use token.payload
    /// }
    /// ```
    ///
    /// - Parameter value: The JWT token string to verify and decode.
    ///
    /// - Note: Consider checking `secondsToExpire > 0` to verify the token is not expired.
    init(stringLiteral value: Self.StringLiteralType) {
        self.value = value
        do {
            signers.use(jwt_signer)
            payload = try signers.verify(self.value, as: Payload.self)
            expirationDate = payload.expiration.value
            secondsToExpire = expirationDate.millisecondsSinceNow / 1000
        } catch {
            Log.error("Cannot initialize Token from value: \(value), because: \(error.localizedDescription)")
            payload = Payload(
                subject: "ERROR",
                expiration: ExpirationClaim(value: Date()),
                tenant: "",
                role: "",
                user: ""
            )
            expirationDate = Date()
            secondsToExpire = 0
        }
    }

    /// Creates a new JWT token for an authenticated user
    ///
    /// Generates a signed JWT token with the specified user information and tenant context.
    /// The token expiration is controlled by the `TOKEN_EXPIRATION_IN_HOURS` environment variable
    /// (defaults to 2 hours if not set).
    ///
    /// - Parameters:
    ///   - tenantName: The name of the tenant this token is issued for
    ///   - subject: The subject claim identifying the user
    ///   - userProfile: User profile information including role and metadata
    /// - Throws: `TokenError.CALCULATE_TIME` if the expiration date cannot be calculated
    ///
    /// ## Example
    /// ```swift
    /// let token = try Token(
    ///     tenantName: "example-tenant",
    ///     subject: "user@example.com",
    ///     userProfile: userProfile
    /// )
    /// ```
    init(tenantName: String, subject: SubjectClaim, userProfile: UserProfileProtocol) throws {
        let expirationHours = Int(ProcessInfo.processInfo.environment["TOKEN_EXPIRATION_IN_HOURS"] ?? "2") ?? 2
        let calendar = Calendar.current
        guard let expirationDate = calendar.date(
            byAdding: .hour,
            value: expirationHours,
            to: Date()
        )
        else {
            throw TokenError.CALCULATE_TIME
        }
        self.expirationDate = expirationDate
        secondsToExpire = expirationHours * 60 * 60

        payload = Payload(
            subject: subject,
            expiration: .init(value: expirationDate),
            tenant: tenantName,
            role: userProfile.role,
            user: userProfile.user,
            profile: userProfile.profile
        )

        signers.use(jwt_signer)
        value = try signers.sign(payload)
    }
}
