import Testing
@testable import Uitsmijter_AuthServer
import JWTKit
import Foundation

typealias Algorithm = SignerManager.Algorithm

@Suite("SignerManager Algorithm Tests")
struct SignerManagerAlgorithmTest {

    @Test("Sign with HS256")
    func signWithHS256() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (token, kid) = try await manager.sign(
            payload,
            algorithm: .hs256
        )

        #expect(!token.isEmpty)
        #expect(kid == nil)

        let parts = token.split(separator: ".")
        #expect(parts.count == 3)
    }

    @Test("Sign with RS256")
    func signWithRS256() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (token, kid) = try await manager.sign(
            payload,
            algorithm: .rs256
        )

        #expect(!token.isEmpty)
        #expect(kid != nil)
        #expect(!kid!.isEmpty)

        let parts = token.split(separator: ".")
        #expect(parts.count == 3)
    }

    @Test("Sign with algorithm string")
    func signWithAlgorithmString() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (hs256Token, hs256Kid) = try await manager.sign(
            payload,
            algorithmString: "HS256"
        )
        #expect(!hs256Token.isEmpty)
        #expect(hs256Kid == nil)

        let (rs256Token, rs256Kid) = try await manager.sign(
            payload,
            algorithmString: "RS256"
        )
        #expect(!rs256Token.isEmpty)
        #expect(rs256Kid != nil)
    }

    @Test("Sign with lowercase algorithm string")
    func signWithLowercaseAlgorithmString() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (hs256Token, hs256Kid) = try await manager.sign(
            payload,
            algorithmString: "hs256"
        )
        #expect(!hs256Token.isEmpty)
        #expect(hs256Kid == nil)

        let (rs256Token, rs256Kid) = try await manager.sign(
            payload,
            algorithmString: "rs256"
        )
        #expect(!rs256Token.isEmpty)
        #expect(rs256Kid != nil)
    }

    @Test("Sign with invalid algorithm string throws error")
    func signWithInvalidAlgorithmString() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        await #expect(throws: SignerError.self) {
            _ = try await manager.sign(payload, algorithmString: "INVALID")
        }
    }

    @Test("Verify HS256 token")
    func verifyHS256Token() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (token, _) = try await manager.sign(payload, algorithm: .hs256)
        let verified = try await manager.verify(token, as: Payload.self)

        #expect(verified.tenant == payload.tenant)
        #expect(verified.user == payload.user)
        #expect(verified.role == payload.role)
    }

    @Test("Verify RS256 token")
    func verifyRS256Token() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (token, _) = try await manager.sign(payload, algorithm: .rs256)
        let verified = try await manager.verify(token, as: Payload.self)

        #expect(verified.tenant == payload.tenant)
        #expect(verified.user == payload.user)
        #expect(verified.role == payload.role)
    }

    @Test("Verify mixed algorithm tokens")
    func verifyMixedAlgorithmTokens() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)

        let payload1 = createTestPayload(tenant: "tenant-hs256")
        let payload2 = createTestPayload(tenant: "tenant-rs256")

        let (hs256Token, _) = try await manager.sign(payload1, algorithm: .hs256)
        let (rs256Token, _) = try await manager.sign(payload2, algorithm: .rs256)

        let verified1 = try await manager.verify(hs256Token, as: Payload.self)
        let verified2 = try await manager.verify(rs256Token, as: Payload.self)

        #expect(verified1.tenant == "tenant-hs256")
        #expect(verified2.tenant == "tenant-rs256")
    }

    @Test("HS256 token has no kid in header")
    func hs256TokenHasNoKidInHeader() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (token, _) = try await manager.sign(payload, algorithm: .hs256)

        let headerPart = String(token.split(separator: ".")[0])
        let headerData = Data(base64Encoded: headerPart.padding(toLength: ((headerPart.count + 3) / 4) * 4,
                                                                  withPad: "=",
                                                                  startingAt: 0))!
        let header = try JSONSerialization.jsonObject(with: headerData) as! [String: Any]

        #expect(header["alg"] as? String == "HS256")
        #expect(header["kid"] == nil)
    }

    @Test("RS256 token has kid in header")
    func rs256TokenHasKidInHeader() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)
        let payload = createTestPayload()

        let (token, kid) = try await manager.sign(payload, algorithm: .rs256)

        let headerPart = String(token.split(separator: ".")[0])
        let headerData = Data(base64Encoded: headerPart.padding(toLength: ((headerPart.count + 3) / 4) * 4,
                                                                  withPad: "=",
                                                                  startingAt: 0))!
        let header = try JSONSerialization.jsonObject(with: headerData) as! [String: Any]

        #expect(header["alg"] as? String == "RS256")
        #expect(header["kid"] != nil)
        #expect(header["kid"] as? String == kid)
    }

    @Test("Multiple RS256 signings use same key")
    func multipleRS256SigningsUseSameKey() async throws {
        let storage = KeyStorage(use: .memory)
        let manager = SignerManager(keyStorage: storage)

        let payload1 = createTestPayload()
        let payload2 = createTestPayload()

        let (_, kid1) = try await manager.sign(payload1, algorithm: .rs256)
        let (_, kid2) = try await manager.sign(payload2, algorithm: .rs256)

        #expect(kid1 == kid2)
    }

    // MARK: - Helper methods

    private func createTestPayload(tenant: String = "test-tenant") -> Payload {
        return Payload(
            issuer: IssuerClaim(value: "test-issuer"),
            subject: SubjectClaim(value: "user@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: tenant,
            role: "user",
            user: "user@example.com"
        )
    }
}
