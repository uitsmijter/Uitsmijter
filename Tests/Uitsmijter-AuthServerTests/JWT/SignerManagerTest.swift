import Foundation
@testable import Uitsmijter_AuthServer
import Testing
import JWTKit

@Suite("SignerManager Tests", .serialized)
// swiftlint:disable type_body_length
struct SignerManagerTest {

    init() async {
        // Note: We don't reset KeyStorage here to maintain key consistency.
        // SignerManager tests use the shared instance to match production behavior.
    }

    // MARK: - Initialization Tests

    @Test("SignerManager shared instance is accessible")
    func signerManagerSharedInstance() {
        let manager = SignerManager.shared
        // Verify shared instance exists (non-optional type)
        _ = manager
        #expect(true)
    }

    // MARK: - HS256 Algorithm Tests

    @Test("Sign payload with HS256")
    func signWithHS256() async throws {
        // Note: This test assumes JWT_ALGORITHM is not set or is set to HS256
        let manager = SignerManager.shared

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "test@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "test@example.com"
        )

        let (token, kid) = try await manager.sign(payload)

        #expect(!token.isEmpty)
        #expect(token.split(separator: ".").count == 3)

        // HS256 should not include kid
        if ProcessInfo.processInfo.environment["JWT_ALGORITHM"] == "HS256"
            || ProcessInfo.processInfo.environment["JWT_ALGORITHM"] == nil {
            #expect(kid == nil)
        }
    }

    @Test("Verify HS256 signed token")
    func verifyHS256Token() async throws {
        let manager = SignerManager.shared

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "verify@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "verify-tenant",
            role: "admin",
            user: "verify@example.com"
        )

        let (token, _) = try await manager.sign(payload)
        let verified = try await manager.verify(token, as: Payload.self)

        #expect(verified.subject.value == "verify@example.com")
        #expect(verified.tenant == "verify-tenant")
        #expect(verified.role == "admin")
    }

    // MARK: - Signing Tests

    @Test("Sign multiple payloads")
    func signMultiplePayloads() async throws {
        let manager = SignerManager.shared

        var tokens: [String] = []

        for i in 0..<5 {
            let payload = Payload(
                issuer: IssuerClaim(value: "https://test.example.com"),
                subject: SubjectClaim(value: "user\(i)@example.com"),
                audience: AudienceClaim(value: "test-client"),
                expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
                issuedAt: IssuedAtClaim(value: Date()),
                authTime: AuthTimeClaim(value: Date()),
                tenant: "test-tenant",
                role: "user",
                user: "user\(i)@example.com"
            )

            let (token, _) = try await manager.sign(payload)
            tokens.append(token)
        }

        #expect(tokens.count == 5)

        // All tokens should be unique
        let uniqueTokens = Set(tokens)
        #expect(uniqueTokens.count == 5)
    }

    @Test("Sign and verify round-trip")
    func signAndVerifyRoundTrip() async throws {
        let manager = SignerManager.shared

        let profile = CodableProfile.object([
            "firstName": .string("John"),
            "lastName": .string("Doe"),
            "email": .string("john.doe@example.com")
        ])

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "john.doe@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "john.doe@example.com",
            profile: profile
        )

        let (token, _) = try await manager.sign(payload)
        let verified = try await manager.verify(token, as: Payload.self)

        #expect(verified.subject.value == payload.subject.value)
        #expect(verified.tenant == payload.tenant)
        #expect(verified.role == payload.role)
        #expect(verified.user == payload.user)
        #expect(verified.profile?.object?["firstName"]?.string == "John")
    }

    // MARK: - Verification Tests

    @Test("Verify rejects tampered tokens")
    func verifyRejectsTamperedTokens() async throws {
        let manager = SignerManager.shared

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "tamper@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "tamper@example.com"
        )

        let (token, _) = try await manager.sign(payload)

        // Tamper with the token
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            Issue.record("Token doesn't have 3 parts")
            return
        }

        let tamperedToken = "\(parts[0]).tampered_payload.\(parts[2])"

        // Verification should fail
        await #expect(throws: Error.self) {
            try await manager.verify(tamperedToken, as: Payload.self)
        }
    }

    @Test("Verify rejects invalid JWT format")
    func verifyRejectsInvalidFormat() async throws {
        let manager = SignerManager.shared

        await #expect(throws: Error.self) {
            try await manager.verify("invalid.jwt", as: Payload.self)
        }
    }

    @Test("Verify rejects empty token")
    func verifyRejectsEmptyToken() async throws {
        let manager = SignerManager.shared

        await #expect(throws: Error.self) {
            try await manager.verify("", as: Payload.self)
        }
    }

    // MARK: - Concurrency Tests

    @Test("Concurrent signing operations")
    func concurrentSigning() async throws {
        let manager = SignerManager.shared

        await withTaskGroup(of: String?.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let payload = Payload(
                        issuer: IssuerClaim(value: "https://test.example.com"),
                        subject: SubjectClaim(value: "concurrent\(i)@example.com"),
                        audience: AudienceClaim(value: "test-client"),
                        expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
                        issuedAt: IssuedAtClaim(value: Date()),
                        authTime: AuthTimeClaim(value: Date()),
                        tenant: "test-tenant",
                        role: "user",
                        user: "concurrent\(i)@example.com"
                    )

                    if let result = try? await manager.sign(payload) {
                        return result.token
                    }
                    return nil
                }
            }

            var tokens: [String] = []
            for await token in group {
                if let token = token {
                    tokens.append(token)
                }
            }

            #expect(tokens.count == 10)
            let uniqueTokens = Set(tokens)
            #expect(uniqueTokens.count == 10)
        }
    }

    @Test("Concurrent verification operations")
    func concurrentVerification() async throws {
        let manager = SignerManager.shared

        // Create a token first
        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "concurrent@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "concurrent@example.com"
        )

        let (token, _) = try await manager.sign(payload)

        // Verify concurrently
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        let verified = try await manager.verify(token, as: Payload.self)
                        return verified.subject.value == "concurrent@example.com"
                    } catch {
                        return false
                    }
                }
            }

            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            #expect(results.count == 10)
            #expect(results.allSatisfy { $0 })
        }
    }

    @Test("Concurrent sign and verify operations")
    func concurrentSignAndVerify() async throws {
        let manager = SignerManager.shared

        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        let payload = Payload(
                            issuer: IssuerClaim(value: "https://test.example.com"),
                            subject: SubjectClaim(value: "mixed\(i)@example.com"),
                            audience: AudienceClaim(value: "test-client"),
                            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
                            issuedAt: IssuedAtClaim(value: Date()),
                            authTime: AuthTimeClaim(value: Date()),
                            tenant: "test-tenant",
                            role: "user",
                            user: "mixed\(i)@example.com"
                        )

                        let (token, _) = try await manager.sign(payload)
                        let verified = try await manager.verify(token, as: Payload.self)
                        return verified.subject.value == "mixed\(i)@example.com"
                    } catch {
                        return false
                    }
                }
            }

            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            #expect(results.count == 10)
            #expect(results.allSatisfy { $0 })
        }
    }

    // MARK: - Edge Cases

    @Test("Sign payload with empty tenant")
    func signWithEmptyTenant() async throws {
        let manager = SignerManager.shared

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "test@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "",
            role: "user",
            user: "test@example.com"
        )

        let (token, _) = try await manager.sign(payload)
        let verified = try await manager.verify(token, as: Payload.self)

        #expect(verified.tenant == "")
    }

    @Test("Sign payload with special characters")
    func signWithSpecialCharacters() async throws {
        let manager = SignerManager.shared

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "user+tag@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "tenant-with-dashes_underscores.dots",
            role: "admin/developer",
            user: "user+tag@example.com"
        )

        let (token, _) = try await manager.sign(payload)
        let verified = try await manager.verify(token, as: Payload.self)

        #expect(verified.subject.value == "user+tag@example.com")
        #expect(verified.tenant == "tenant-with-dashes_underscores.dots")
        #expect(verified.role == "admin/developer")
    }

    @Test("Sign payload with unicode characters")
    func signWithUnicodeCharacters() async throws {
        let manager = SignerManager.shared

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "用户@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "租户-テナント",
            role: "Administrador",
            user: "用户名"
        )

        let (token, _) = try await manager.sign(payload)
        let verified = try await manager.verify(token, as: Payload.self)

        #expect(verified.subject.value == "用户@example.com")
        #expect(verified.tenant == "租户-テナント")
        #expect(verified.role == "Administrador")
        #expect(verified.user == "用户名")
    }

    @Test("Sign payload with complex profile")
    func signWithComplexProfile() async throws {
        let manager = SignerManager.shared

        let profile = CodableProfile.object([
            "user": .object([
                "name": .object([
                    "first": .string("John"),
                    "last": .string("Doe")
                ]),
                "permissions": .array([
                    .string("read"),
                    .string("write"),
                    .string("execute")
                ]),
                "metadata": .object([
                    "createdAt": .string("2024-01-01"),
                    "department": .string("Engineering")
                ])
            ])
        ])

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "complex@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "complex@example.com",
            profile: profile
        )

        let (token, _) = try await manager.sign(payload)
        let verified = try await manager.verify(token, as: Payload.self)

        let userObj = verified.profile?.object?["user"]?.object
        #expect(userObj?["name"]?.object?["first"]?.string == "John")
        #expect(userObj?["permissions"]?.array?.count == 3)
        #expect(userObj?["metadata"]?.object?["department"]?.string == "Engineering")
    }

    // MARK: - Algorithm Detection Tests

    @Test("Signed token has correct algorithm in header")
    func signedTokenHasCorrectAlgorithm() async throws {
        let manager = SignerManager.shared

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "test@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "test@example.com"
        )

        let (token, kid) = try await manager.sign(payload)

        // Decode header
        let parts = token.split(separator: ".")
        #expect(parts.count == 3)

        let headerString = String(parts[0])
        let base64 = headerString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

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

        // Check algorithm
        if ProcessInfo.processInfo.environment["JWT_ALGORITHM"] == "RS256" {
            #expect(headerJson?["alg"] as? String == "RS256")
            #expect(headerJson?["kid"] as? String == kid)
        } else {
            #expect(headerJson?["alg"] as? String == "HS256")
        }
    }
}
// swiftlint:enable type_body_length
