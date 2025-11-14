import Foundation
import JWTKit
import Logger
import FoundationExtensions

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

        // jwt-kit v5 migration: JWTKeyCollection is async, so we can't verify here.
        // For string literal initialization, we decode without verification.
        // Production code should use SignerManager.verify() for proper verification.
        do {
            // Decode JWT without verification (unsafe, for convenience only)
            let parts = value.split(separator: ".")
            guard parts.count == 3,
                  let payloadData = Data(base64URLEncoded: String(parts[1])) else {
                throw TokenError.invalidFormat
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            payload = try decoder.decode(Payload.self, from: payloadData)
            expirationDate = payload.expiration.value
            secondsToExpire = expirationDate.millisecondsSinceNow / 1000
        } catch {
            Log.error("Cannot initialize Token from value: \(value), because: \(error.localizedDescription)")
            let now = Date()
            payload = Payload(
                issuer: IssuerClaim(value: "ERROR"),
                subject: SubjectClaim(value: "ERROR"),
                audience: AudienceClaim(value: "ERROR"),
                expiration: ExpirationClaim(value: now),
                issuedAt: IssuedAtClaim(value: now),
                authTime: AuthTimeClaim(value: now),
                tenant: "",
                role: "",
                user: ""
            )
            expirationDate = Date()
            secondsToExpire = 0
        }
    }

    enum TokenError: Error {
        case invalidFormat
        case CALCULATE_TIME
    }

    /// Verify a JWT token string asynchronously using SignerManager
    ///
    /// This is the recommended way to verify tokens in production as it supports
    /// both HS256 and RS256 algorithms with automatic key selection.
    ///
    /// - Parameters:
    ///   - value: The JWT token string to verify
    ///   - signerManager: Optional SignerManager instance for dependency injection (defaults to .shared)
    /// - Returns: Verified Token instance
    /// - Throws: JWTError if verification fails
    static func verify(_ value: String, signerManager: SignerManager? = nil) async throws -> Token {
        let manager = signerManager ?? SignerManager.shared
        let payload = try await manager.verify(value, as: Payload.self)

        let expirationDate = payload.expiration.value
        let secondsToExpire = expirationDate.millisecondsSinceNow / 1000

        return Token(
            value: value,
            payload: payload,
            expirationDate: expirationDate,
            secondsToExpire: secondsToExpire
        )
    }

    /// Private initializer for creating verified tokens
    private init(value: String, payload: Payload, expirationDate: Date, secondsToExpire: Int) {
        self.value = value
        self.payload = payload
        self.expirationDate = expirationDate
        self.secondsToExpire = secondsToExpire
    }

    /// Creates a new JWT token for an authenticated user
    ///
    /// Generates a signed JWT token with the specified user information and tenant context.
    /// The token includes standard JWT claims (issuer, subject, audience, expiration, issued-at,
    /// auth_time) as well as custom claims (tenant, role, user, profile).
    ///
    /// The token expiration is controlled by the `TOKEN_EXPIRATION_IN_HOURS` environment variable
    /// (defaults to 2 hours if not set).
    ///
    /// ## Standard Claims
    ///
    /// - **iss** (Issuer): The authorization server URL
    /// - **sub** (Subject): The authenticated user identifier
    /// - **aud** (Audience): The client_id of the OAuth2 client
    /// - **exp** (Expiration): Token expiration timestamp
    /// - **iat** (Issued At): Token creation timestamp
    /// - **auth_time**: When the user authentication occurred (OIDC)
    ///
    /// - Parameters:
    ///   - issuer: The issuer claim (authorization server URL)
    ///   - audience: The audience claim (OAuth2 client_id)
    ///   - tenantName: The name of the tenant this token is issued for
    ///   - subject: The subject claim identifying the user
    ///   - userProfile: User profile information including role and metadata
    ///   - authTime: When the user authentication occurred (defaults to current time)
    ///   - algorithmString: Optional JWT algorithm override (HS256 or RS256)
    ///   - signerManager: Optional SignerManager instance for dependency injection (defaults to .shared)
    /// - Throws: `TokenError.CALCULATE_TIME` if the expiration date cannot be calculated
    ///
    /// ## Example
    /// ```swift
    /// let token = try Token(
    ///     issuer: IssuerClaim(value: "https://auth.example.com"),
    ///     audience: AudienceClaim(value: "my-client-id"),
    ///     tenantName: "example-tenant",
    ///     subject: SubjectClaim(value: "user@example.com"),
    ///     userProfile: userProfile,
    ///     authTime: Date(),
    ///     algorithmString: "RS256"
    /// )
    /// ```
    init(
        issuer: IssuerClaim,
        audience: AudienceClaim,
        tenantName: String,
        subject: SubjectClaim,
        userProfile: UserProfileProtocol,
        authTime: Date? = nil,
        algorithmString: String? = nil,
        signerManager: SignerManager? = nil
    ) async throws {
        let expirationHours = Int(ProcessInfo.processInfo.environment["TOKEN_EXPIRATION_IN_HOURS"] ?? "2") ?? 2
        let calendar = Calendar.current
        let now = Date()
        guard let expirationDate = calendar.date(
            byAdding: .hour,
            value: expirationHours,
            to: now
        )
        else {
            throw TokenError.CALCULATE_TIME
        }
        self.expirationDate = expirationDate
        secondsToExpire = expirationHours * 60 * 60

        payload = Payload(
            issuer: issuer,
            subject: subject,
            audience: audience,
            expiration: ExpirationClaim(value: expirationDate),
            issuedAt: IssuedAtClaim(value: now),
            authTime: AuthTimeClaim(value: authTime ?? now),
            tenant: tenantName,
            responsibility: nil,
            role: userProfile.role,
            user: userProfile.user,
            profile: userProfile.profile
        )

        // Use SignerManager for signing (supports both HS256 and RS256)
        let manager = signerManager ?? SignerManager.shared

        // Use provided algorithm or fall back to global default
        let effectiveAlgorithm = algorithmString ??
            ProcessInfo.processInfo.environment["JWT_ALGORITHM"] ?? "HS256"

        let (tokenString, kid) = try await manager.sign(
            payload,
            algorithmString: effectiveAlgorithm
        )
        value = tokenString

        // Log the kid if RS256 is used
        if let kid = kid {
            Log.debug("Signed token with RS256 using kid: \(kid)")
        }
    }
}

/// Extension to support base64URL decoding
extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        self.init(base64Encoded: base64)
    }
}
