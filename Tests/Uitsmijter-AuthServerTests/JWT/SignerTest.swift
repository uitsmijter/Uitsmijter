import Foundation
@testable import Uitsmijter_AuthServer
import Testing
import JWTKit

@Suite("JWT Signer Tests")
// swiftlint:disable type_body_length
struct SignerTest {

    // MARK: - jwt_signer Initialization Tests

    @Test("jwt_signer is initialized and available")
    func jwtSignerIsInitialized() async throws {
        // Verify SignerManager.shared is accessible
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "test@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "test@example.com",
            scope: nil
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)
        #expect(!tokenString.isEmpty)
    }

    @Test("jwt_signer can sign a simple payload")
    func jwtSignerCanSign() async throws {
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "test@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "test@example.com",
            scope: nil
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)

        // Verify token is generated
        #expect(!tokenString.isEmpty)
        // JWT tokens have three parts separated by dots
        let parts = tokenString.split(separator: ".")
        #expect(parts.count == 3)
    }

    @Test("jwt_signer can verify a signed payload")
    func jwtSignerCanVerify() async throws {
        let expirationDate = Date(timeIntervalSinceNow: 3600)
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "verify@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: expirationDate),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "verify-tenant",
            role: "admin",
            user: "verify@example.com",
            scope: "openid email"
        )

        // Sign the payload
        let (tokenString, _) = try await SignerManager.shared.sign(payload)

        // Verify and decode the token
        let verifiedPayload = try await SignerManager.shared.verify(tokenString, as: Payload.self)

        // Check that payload matches
        #expect(verifiedPayload.subject.value == "verify@example.com")
        #expect(verifiedPayload.tenant == "verify-tenant")
        #expect(verifiedPayload.role == "admin")
        #expect(verifiedPayload.user == "verify@example.com")
    }

    @Test("jwt_signer rejects tampered tokens")
    func jwtSignerRejectsTamperedTokens() async throws {
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "tamper@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "tamper@example.com",
            scope: "openid email"
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)

        // Tamper with the token (change a character in the payload section)
        let parts = tokenString.split(separator: ".")
        guard parts.count == 3 else {
            Issue.record("Token doesn't have 3 parts")
            return
        }

        // Modify the payload part
        var tamperedPayload = String(parts[1])
        if let lastChar = tamperedPayload.last, lastChar == "A" {
            tamperedPayload.removeLast()
            tamperedPayload.append("B")
        } else {
            tamperedPayload.removeLast()
            tamperedPayload.append("A")
        }

        let tamperedToken = "\(parts[0]).\(tamperedPayload).\(parts[2])"

        // Verification should fail
        await #expect(throws: Error.self) {
            try await SignerManager.shared.verify(tamperedToken, as: Payload.self)
        }
    }

    @Test("jwt_signer uses HS256 algorithm")
    func jwtSignerUsesHS256() async throws {
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "hs256@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "hs256@example.com",
            scope: "openid email"
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)

        // Decode the header to check algorithm
        let parts = tokenString.split(separator: ".")
        #expect(parts.count == 3)

        // Decode base64url header
        let header = String(parts[0])
        let base64 = header
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddedBase64: String
        let remainder = base64.count % 4
        if remainder > 0 {
            paddedBase64 = base64 + String(repeating: "=", count: 4 - remainder)
        } else {
            paddedBase64 = base64
        }

        guard let headerData = Data(base64Encoded: paddedBase64) else {
            Issue.record("Failed to decode header")
            return
        }

        let headerJson = try JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        #expect(headerJson?["alg"] as? String == "HS256")
    }

    @Test("jwt_signer produces consistent signatures")
    func jwtSignerConsistentSignatures() async throws {
        let expirationDate = Date(timeIntervalSinceNow: 3600)
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "consistent@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: expirationDate),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "consistent@example.com",
            scope: "openid email foo:bar"
        )

        // Sign the same payload twice
        let (tokenString1, _) = try await SignerManager.shared.sign(payload)
        let (tokenString2, _) = try await SignerManager.shared.sign(payload)

        // Both tokens should be valid and decode to equivalent payloads
        // Note: In Swift 6, dictionary encoding order is not guaranteed, so byte-for-byte
        // equality is not reliable. Instead, verify both tokens are valid and semantically equal.
        let decoded1 = try await SignerManager.shared.verify(tokenString1, as: Payload.self)
        let decoded2 = try await SignerManager.shared.verify(tokenString2, as: Payload.self)

        #expect(decoded1.subject == decoded2.subject)
        #expect(decoded1.tenant == decoded2.tenant)
        #expect(decoded1.role == decoded2.role)
        #expect(decoded1.user == decoded2.user)
        let timeDifference = abs(
            decoded1.expiration.value.timeIntervalSince1970 - decoded2.expiration.value.timeIntervalSince1970
        )
        #expect(timeDifference < 0.001)
    }

    @Test("jwt_signer handles payload with optional fields")
    func jwtSignerHandlesOptionalFields() async throws {
        let profile = CodableProfile.object([
            "firstName": .string("John"),
            "lastName": .string("Doe")
        ])

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "optional@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            responsibility: "admin-domain",
            role: "admin",
            user: "optional@example.com",
            scope: "foo:bar openid",
            profile: profile
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)

        // Verify and decode
        let verified = try await SignerManager.shared.verify(tokenString, as: Payload.self)
        #expect(verified.responsibility == "admin-domain")
        #expect(verified.profile != nil)
        #expect(verified.profile?.object?["firstName"]?.string == "John")
    }

    @Test("jwt_signer can verify tokens with different expiration times")
    func jwtSignerDifferentExpirations() async throws {
        let shortExpiration = Date(timeIntervalSinceNow: 60) // 1 minute
        let longExpiration = Date(timeIntervalSinceNow: 86_400) // 24 hours

        let payload1 = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "short@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: shortExpiration),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "short@example.com",
            scope: "foo:bar can:all"
        )

        let payload2 = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "long@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: longExpiration),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "long@example.com",
            scope: "foo:bar can:all"
        )

        let (tokenString1, _) = try await SignerManager.shared.sign(payload1)
        let (tokenString2, _) = try await SignerManager.shared.sign(payload2)

        // Both should verify successfully
        let verified1 = try await SignerManager.shared.verify(tokenString1, as: Payload.self)
        let verified2 = try await SignerManager.shared.verify(tokenString2, as: Payload.self)

        #expect(verified1.subject.value == "short@example.com")
        #expect(verified2.subject.value == "long@example.com")
    }

    @Test("jwt_signer handles empty strings in payload")
    func jwtSignerHandlesEmptyStrings() async throws {
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "",
            role: "",
            user: "",
            scope: ""
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)
        let verified = try await SignerManager.shared.verify(tokenString, as: Payload.self)

        #expect(verified.subject.value == "")
        #expect(verified.tenant == "")
        #expect(verified.role == "")
        #expect(verified.user == "")
    }

    @Test("jwt_signer handles special characters in payload")
    func jwtSignerHandlesSpecialCharacters() async throws {
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "user+test@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "tenant-with-dashes_and_underscores",
            role: "admin/developer",
            user: "user@example.com (John Doe)",
            scope: "admin"
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)
        let verified = try await SignerManager.shared.verify(tokenString, as: Payload.self)

        #expect(verified.subject.value == "user+test@example.com")
        #expect(verified.tenant == "tenant-with-dashes_and_underscores")
        #expect(verified.role == "admin/developer")
        #expect(verified.user == "user@example.com (John Doe)")
    }

    @Test("jwt_signer handles unicode characters")
    func jwtSignerHandlesUnicode() async throws {
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "用户@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "租户-テナント",
            role: "Administrador",
            user: "用户名",
            scope: "admin"
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)
        let verified = try await SignerManager.shared.verify(tokenString, as: Payload.self)

        #expect(verified.subject.value == "用户@example.com")
        #expect(verified.tenant == "租户-テナント")
        #expect(verified.role == "Administrador")
        #expect(verified.user == "用户名")
    }

    @Test("jwt_signer token format is valid JWT")
    func jwtSignerProducesValidJWTFormat() async throws {
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: "format@example.com",
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "format@example.com",
            scope: "user:list"
        )

        let (tokenString, _) = try await SignerManager.shared.sign(payload)

        // JWT format: header.payload.signature
        let parts = tokenString.split(separator: ".")
        #expect(parts.count == 3)

        // Each part should be base64url encoded (alphanumeric plus - and _)
        let base64urlPattern = "^[A-Za-z0-9_-]+$"
        for part in parts {
            let matches = String(part).range(of: base64urlPattern, options: .regularExpression)
            #expect(matches != nil)
        }
    }

    @Test("jwt_signer can sign multiple payloads sequentially")
    func jwtSignerMultipleSequentialSigns() async throws {
        var tokens: [String] = []

        for i in 0..<10 {
            let payload = Payload(
                issuer: IssuerClaim(value: "https://test.example.com"),
                subject: SubjectClaim(value: "user\(i)@example.com"),
                audience: AudienceClaim(value: "test-client"),
                expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
                issuedAt: IssuedAtClaim(value: Date()),
                authTime: AuthTimeClaim(value: Date()),
                tenant: "test-tenant",
                role: "user",
                user: "user\(i)@example.com",
                scope: "id"
            )

            let (tokenString, _) = try await SignerManager.shared.sign(payload)
            tokens.append(tokenString)
        }

        // All tokens should be unique
        let uniqueTokens = Set(tokens)
        #expect(uniqueTokens.count == 10)

        // All tokens should verify
        for (i, token) in tokens.enumerated() {
            let verified = try await SignerManager.shared.verify(token, as: Payload.self)
            #expect(verified.subject.value == "user\(i)@example.com")
        }
    }
}
// swiftlint:enable type_body_length
