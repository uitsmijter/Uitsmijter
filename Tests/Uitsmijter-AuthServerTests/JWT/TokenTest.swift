// swiftlint:disable file_length
@testable import Uitsmijter_AuthServer
import Foundation
import Testing
import JWTKit
import Logger

@Suite("JWT Token Tests", .serialized)
// swiftlint:disable type_body_length
// Note: We don't reset KeyStorage to maintain key consistency
// between token signing and verification within tests.
struct TokenTest {

    // MARK: - Token Creation Tests

    @Test("Create token with user profile")
    func createTokenWithUserProfile() async throws {
        let userProfile = UserProfile(
            role: "admin",
            user: "admin@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "admin@example.com"),
            userProfile: userProfile
        )

        // Verify token properties
        #expect(!token.value.isEmpty)
        #expect(token.payload.subject.value == "admin@example.com")
        #expect(token.payload.tenant == "test-tenant")
        #expect(token.payload.role == "admin")
        #expect(token.payload.user == "admin@example.com")
        #expect(token.secondsToExpire > 0)
        #expect(token.expirationDate > Date())
    }

    @Test("Token expiration defaults to 2 hours")
    func tokenDefaultExpiration() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        // Default is 2 hours = 7200 seconds
        // Allow small tolerance for test execution time
        #expect(token.secondsToExpire >= 7190)
        #expect(token.secondsToExpire <= 7210)

        // Verify expiration date is approximately 2 hours from now
        let expectedExpiration = Date(timeIntervalSinceNow: 7200)
        let timeDiff = abs(token.expirationDate.timeIntervalSince(expectedExpiration))
        #expect(timeDiff < 10) // Within 10 seconds tolerance
    }

    @Test("Token includes profile data")
    func tokenIncludesProfileData() async throws {
        let profile = CodableProfile.object([
            "firstName": .string("John"),
            "lastName": .string("Doe"),
            "email": .string("john.doe@example.com"),
            "age": .integer(30)
        ])

        let userProfile = UserProfile(
            role: "user",
            user: "john.doe@example.com",
            profile: profile
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "john.doe@example.com"),
            userProfile: userProfile
        )

        // Verify profile is included
        #expect(token.payload.profile != nil)
        #expect(token.payload.profile?.object?["firstName"]?.string == "John")
        #expect(token.payload.profile?.object?["lastName"]?.string == "Doe")
        #expect(token.payload.profile?.object?["email"]?.string == "john.doe@example.com")
        #expect(token.payload.profile?.object?["age"]?.int == 30)
    }

    @Test("Token can be created and verified")
    func tokenCreationAndVerification() async throws {
        let userProfile = UserProfile(
            role: "developer",
            user: "dev@example.com"
        )

        let createdToken = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "dev-tenant",
            subject: SubjectClaim(value: "dev@example.com"),
            userProfile: userProfile
        )

        // Create another token from the string value using async verify
        let verifiedToken = try await Token.verify(createdToken.value)

        // Both should have the same payload data
        #expect(verifiedToken.payload.subject.value == "dev@example.com")
        #expect(verifiedToken.payload.tenant == "dev-tenant")
        #expect(verifiedToken.payload.role == "developer")
        #expect(verifiedToken.payload.user == "dev@example.com")
    }

    @Test("Token value is valid JWT format")
    func tokenValueIsValidJWT() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        // JWT format: header.payload.signature
        let parts = token.value.split(separator: ".")
        #expect(parts.count == 3)

        // Each part should be base64url encoded
        for part in parts {
            #expect(!part.isEmpty)
            // Base64url uses alphanumeric, -, and _
            let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
            let partChars = CharacterSet(charactersIn: String(part))
            #expect(partChars.isSubset(of: validChars))
        }
    }

    @Test("Multiple tokens have unique signatures")
    func multipleTokensAreUnique() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token1 = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "tenant1",
            subject: SubjectClaim(value: "user1@example.com"),
            userProfile: userProfile
        )

        let token2 = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "tenant2",
            subject: SubjectClaim(value: "user2@example.com"),
            userProfile: userProfile
        )

        // Tokens should be different
        #expect(token1.value != token2.value)
        #expect(token1.payload.subject.value != token2.payload.subject.value)
        #expect(token1.payload.tenant != token2.payload.tenant)
    }

    // MARK: - Token Initialization from String Tests

    @Test("Initialize token from valid JWT string")
    func initializeFromValidJWT() async throws {
        // Create a token first
        let userProfile = UserProfile(
            role: "user",
            user: "test@example.com"
        )

        let originalToken = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "test@example.com"),
            userProfile: userProfile
        )

        // Initialize from string using async verify
        let tokenFromString = try await Token.verify(originalToken.value)

        // Should match original
        #expect(tokenFromString.payload.subject.value == "test@example.com")
        #expect(tokenFromString.payload.tenant == "test-tenant")
        #expect(tokenFromString.payload.role == "user")
        #expect(tokenFromString.payload.user == "test@example.com")
    }

    @Test("Initialize token from invalid JWT returns error token")
    func initializeFromInvalidJWT() throws {
        let invalidToken: Token = "invalid.jwt.token"

        // Should create error token
        #expect(invalidToken.value == "invalid.jwt.token")
        #expect(invalidToken.payload.subject.value == "ERROR")
        #expect(invalidToken.payload.tenant == "")
        #expect(invalidToken.payload.role == "")
        #expect(invalidToken.payload.user == "")
        #expect(invalidToken.secondsToExpire == 0)
    }

    @Test("Initialize token from tampered JWT returns error token")
    func initializeFromTamperedJWT() async throws {
        // Create a valid token first
        let userProfile = UserProfile(
            role: "user",
            user: "test@example.com"
        )

        let validToken = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "test@example.com"),
            userProfile: userProfile
        )

        // Tamper with the token
        let parts = validToken.value.split(separator: ".")
        let tamperedToken = "\(parts[0]).tampered_payload.\(parts[2])"

        let token: Token = Token(stringLiteral: tamperedToken)

        // Should create error token
        #expect(token.payload.subject.value == "ERROR")
        #expect(token.secondsToExpire == 0)
    }

    @Test("Initialize token from empty string returns error token")
    func initializeFromEmptyString() throws {
        let token: Token = ""

        #expect(token.value == "")
        #expect(token.payload.subject.value == "ERROR")
        #expect(token.secondsToExpire == 0)
    }

    // MARK: - Token Expiration Tests

    @Test("Token expiration can be read from secondsToExpire")
    func tokenExpirationSeconds() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        // Default 2 hours = 7200 seconds
        #expect(token.secondsToExpire > 7000)
        #expect(token.secondsToExpire <= 7200)
    }

    @Test("Token expiration date is in the future")
    func tokenExpirationDateInFuture() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        #expect(token.expirationDate > Date())

        // Should be approximately 2 hours from now
        let twoHoursFromNow = Date(timeIntervalSinceNow: 7200)
        let timeDiff = abs(token.expirationDate.timeIntervalSince(twoHoursFromNow))
        #expect(timeDiff < 10)
    }

    @Test("Expired token is detected on initialization")
    func expiredTokenDetection() throws {
        // Create a token with expired date
        let expiredDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "expired@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: expiredDate),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "expired@example.com"
        )

        let signers = JWTSigners()
        signers.use(jwt_signer)
        let expiredTokenString = try signers.sign(payload)

        // Initialize token from expired string
        let token: Token = Token(stringLiteral: expiredTokenString)

        // Token should be initialized but with expired date
        #expect(token.expirationDate < Date())
        // secondsToExpire will be negative (milliseconds/1000)
        #expect(token.secondsToExpire <= 0)
    }

    // MARK: - Token with Different Tenants Tests

    @Test("Token with different tenants")
    func tokenWithDifferentTenants() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token1 = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "tenant-a",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        let token2 = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "tenant-b",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        #expect(token1.payload.tenant == "tenant-a")
        #expect(token2.payload.tenant == "tenant-b")
        #expect(token1.value != token2.value)
    }

    @Test("Token with empty tenant name")
    func tokenWithEmptyTenant() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.tenant == "")
        #expect(!token.value.isEmpty)
    }

    @Test("Token with special characters in tenant")
    func tokenWithSpecialCharactersTenant() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "tenant-with-dashes_underscores.dots",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.tenant == "tenant-with-dashes_underscores.dots")
    }

    // MARK: - Token with Different Roles Tests

    @Test("Token with admin role")
    func tokenWithAdminRole() async throws {
        let userProfile = UserProfile(
            role: "admin",
            user: "admin@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "admin@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.role == "admin")
    }

    @Test("Token with custom role")
    func tokenWithCustomRole() async throws {
        let userProfile = UserProfile(
            role: "power-user",
            user: "power@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "power@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.role == "power-user")
    }

    @Test("Token with empty role")
    func tokenWithEmptyRole() async throws {
        let userProfile = UserProfile(
            role: "",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.role == "")
    }

    // MARK: - Token with Complex Profiles Tests

    @Test("Token with nested profile data")
    func tokenWithNestedProfile() async throws {
        let profile = CodableProfile.object([
            "user": .object([
                "name": .object([
                    "first": .string("John"),
                    "last": .string("Doe")
                ]),
                "contact": .object([
                    "email": .string("john.doe@example.com"),
                    "phone": .string("+1234567890")
                ])
            ])
        ])

        let userProfile = UserProfile(
            role: "user",
            user: "john.doe@example.com",
            profile: profile
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "john.doe@example.com"),
            userProfile: userProfile
        )

        // Verify nested structure
        let userObj = token.payload.profile?.object?["user"]?.object
        #expect(userObj?["name"]?.object?["first"]?.string == "John")
        #expect(userObj?["contact"]?.object?["email"]?.string == "john.doe@example.com")
    }

    @Test("Token with profile containing arrays")
    func tokenWithProfileArrays() async throws {
        let profile = CodableProfile.object([
            "permissions": .array([
                .string("read"),
                .string("write"),
                .string("execute")
            ]),
            "groups": .array([
                .string("admin"),
                .string("developers")
            ])
        ])

        let userProfile = UserProfile(
            role: "admin",
            user: "admin@example.com",
            profile: profile
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "admin@example.com"),
            userProfile: userProfile
        )

        let permissions = token.payload.profile?.object?["permissions"]?.array
        #expect(permissions?.count == 3)
        #expect(permissions?[0].string == "read")
        #expect(permissions?[1].string == "write")
        #expect(permissions?[2].string == "execute")
    }

    @Test("Token with nil profile")
    func tokenWithNilProfile() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com",
            profile: nil
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.profile == nil)
    }

    // MARK: - Token with Special Characters Tests

    @Test("Token with special characters in subject")
    func tokenWithSpecialCharactersSubject() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user+tag@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user+tag@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.subject.value == "user+tag@example.com")
    }

    @Test("Token with unicode characters")
    func tokenWithUnicodeCharacters() async throws {
        let userProfile = UserProfile(
            role: "管理者",
            user: "用户@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "租户",
            subject: SubjectClaim(value: "用户@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.subject.value == "用户@example.com")
        #expect(token.payload.tenant == "租户")
        #expect(token.payload.role == "管理者")
        #expect(token.payload.user == "用户@example.com")
    }

    // MARK: - Round-trip Token Tests

    @Test("Token round-trip preserves all data")
    func tokenRoundTrip() async throws {
        let profile = CodableProfile.object([
            "department": .string("Engineering"),
            "level": .integer(5)
        ])

        let userProfile = UserProfile(
            role: "senior-developer",
            user: "senior@example.com",
            profile: profile
        )

        let originalToken = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "engineering-tenant",
            subject: SubjectClaim(value: "senior@example.com"),
            userProfile: userProfile
        )

        // Round-trip through string using async verify
        let reconstructedToken = try await Token.verify(originalToken.value)

        // All data should be preserved
        #expect(reconstructedToken.payload.subject.value == originalToken.payload.subject.value)
        #expect(reconstructedToken.payload.tenant == originalToken.payload.tenant)
        #expect(reconstructedToken.payload.role == originalToken.payload.role)
        #expect(reconstructedToken.payload.user == originalToken.payload.user)
        #expect(reconstructedToken.payload.profile?.object?["department"]?.string == "Engineering")
        #expect(reconstructedToken.payload.profile?.object?["level"]?.int == 5)
    }

    @Test("Token serialization and deserialization")
    func tokenSerializationDeserialization() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        // Simulate storing token value (e.g., in cookie or database)
        let storedTokenValue = token.value

        // Later, reconstruct token from stored value using async verify
        let retrievedToken = try await Token.verify(storedTokenValue)

        #expect(retrievedToken.payload.subject.value == "user@example.com")
        #expect(retrievedToken.payload.tenant == "test-tenant")
    }

    // MARK: - TokenError Tests

    @Test("TokenError cases exist")
    func tokenErrorCases() {
        // Verify error cases are defined
        let calculateTimeError = TokenError.CALCULATE_TIME
        let noPayloadError = TokenError.NO_PAYLOAD

        // TokenError conforms to Error protocol, verify cases exist
        let errors: [TokenError] = [calculateTimeError, noPayloadError]
        #expect(errors.count == 2)
    }

    // MARK: - Edge Cases

    @Test("Token with very long subject")
    func tokenWithVeryLongSubject() async throws {
        let longSubject = String(repeating: "a", count: 1000) + "@example.com"
        let userProfile = UserProfile(
            role: "user",
            user: longSubject
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: longSubject),
            userProfile: userProfile
        )

        #expect(token.payload.subject.value == longSubject)
    }

    @Test("Token with very long tenant name")
    func tokenWithVeryLongTenant() async throws {
        let longTenant = String(repeating: "tenant-", count: 100)
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: longTenant,
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        #expect(token.payload.tenant == longTenant)
    }

    @Test("Multiple tokens created rapidly")
    func multipleTokensCreatedRapidly() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        var tokens: [Token] = []

        for i in 0..<100 {
            let token = try await Token(
                issuer: IssuerClaim(value: "https://test.example.com"),
                audience: AudienceClaim(value: "test-client"),
                tenantName: "tenant-\(i)",
                subject: SubjectClaim(value: "user\(i)@example.com"),
                userProfile: userProfile
            )
            tokens.append(token)
        }

        // All tokens should be valid and unique
        #expect(tokens.count == 100)
        let uniqueValues = Set(tokens.map { $0.value })
        #expect(uniqueValues.count == 100)
    }

    @Test("Token payload expiration claim is valid")
    func tokenPayloadExpirationValid() async throws {
        let userProfile = UserProfile(
            role: "user",
            user: "user@example.com"
        )

        let token = try await Token(
            issuer: IssuerClaim(value: "https://test.example.com"),
            audience: AudienceClaim(value: "test-client"),
            tenantName: "test-tenant",
            subject: SubjectClaim(value: "user@example.com"),
            userProfile: userProfile
        )

        // Expiration claim should be in the future
        #expect(token.payload.expiration.value > Date())

        // Should be able to verify using SignerManager
        let verified = try await Token.verify(token.value)
        #expect(verified.payload.expiration.value > Date())
    }
}
// swiftlint:enable type_body_length
