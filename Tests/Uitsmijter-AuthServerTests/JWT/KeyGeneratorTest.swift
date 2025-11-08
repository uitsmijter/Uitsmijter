import Foundation
@testable import Uitsmijter_AuthServer
import Testing
import JWTKit

@Suite("KeyGenerator Tests", .serialized)
struct KeyGeneratorTest {

    // MARK: - Key Generation Tests

    @Test("Generate RSA key pair with valid kid")
    func generateKeyPairWithKid() async throws {
        let generator = KeyGenerator()
        let kid = "test-key-2024-01-01"

        let keyPair = try await generator.generateKeyPair(kid: kid)

        #expect(!keyPair.privateKeyPEM.isEmpty)
        #expect(!keyPair.publicKeyPEM.isEmpty)
        #expect(keyPair.kid == kid)
        #expect(keyPair.algorithm == "RS256")
    }

    @Test("Generate multiple key pairs with unique kids")
    func generateMultipleKeyPairs() async throws {
        let generator = KeyGenerator()

        let keyPair1 = try await generator.generateKeyPair(kid: "key-1")
        let keyPair2 = try await generator.generateKeyPair(kid: "key-2")

        #expect(keyPair1.kid != keyPair2.kid)
        #expect(keyPair1.privateKeyPEM != keyPair2.privateKeyPEM)
        #expect(keyPair1.publicKeyPEM != keyPair2.publicKeyPEM)
    }

    @Test("Generated private key PEM has correct format")
    func privateKeyPEMFormat() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "format-test")

        // PKCS#8 format (not PKCS#1)
        #expect(keyPair.privateKeyPEM.hasPrefix("-----BEGIN PRIVATE KEY-----"))
        #expect(keyPair.privateKeyPEM.hasSuffix("-----END PRIVATE KEY-----\n"))
        #expect(keyPair.privateKeyPEM.contains("\n"))
    }

    @Test("Generated public key PEM has correct format")
    func publicKeyPEMFormat() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "public-test")

        // SPKI format (not PKCS#1)
        #expect(keyPair.publicKeyPEM.hasPrefix("-----BEGIN PUBLIC KEY-----"))
        #expect(keyPair.publicKeyPEM.hasSuffix("-----END PUBLIC KEY-----\n"))
        #expect(keyPair.publicKeyPEM.contains("\n"))
    }

    @Test("Generated key pair can be loaded by JWTKit")
    func keyPairCompatibleWithJWTKit() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "jwt-test")

        // JWTKit should be able to load the private key PEM
        let rsaKey = try RSAKey.private(pem: keyPair.privateKeyPEM)
        #expect(rsaKey != nil)
    }

    // MARK: - JWK Conversion Tests

    @Test("Convert key pair to JWK format")
    func convertToJWK() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "jwk-test")

        let jwk = try await generator.convertToJWK(keyPair: keyPair)

        #expect(jwk.kty == "RSA")
        #expect(jwk.use == "sig")
        #expect(jwk.kid == "jwk-test")
        #expect(jwk.alg == "RS256")
        #expect(!jwk.n.isEmpty)
        #expect(!jwk.e.isEmpty)
    }

    @Test("JWK exponent is standard value")
    func jwkExponentIsStandard() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "exp-test")

        let jwk = try await generator.convertToJWK(keyPair: keyPair)

        // Standard exponent is 65537 which encodes to "AQAB" in base64url
        #expect(jwk.e == "AQAB")
    }

    @Test("JWK modulus is properly base64url encoded")
    func jwkModulusEncoding() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "mod-test")

        let jwk = try await generator.convertToJWK(keyPair: keyPair)

        // Base64url uses alphanumeric, -, and _ only (no padding)
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let modulusChars = CharacterSet(charactersIn: jwk.n)
        #expect(modulusChars.isSubset(of: validChars))

        // Should not contain padding
        #expect(!jwk.n.contains("="))

        // Modulus should be long (2048-bit key)
        #expect(jwk.n.count > 300)
    }

    @Test("Multiple key pairs produce different JWKs")
    func multipleJWKsAreDifferent() async throws {
        let generator = KeyGenerator()

        let keyPair1 = try await generator.generateKeyPair(kid: "jwk-1")
        let keyPair2 = try await generator.generateKeyPair(kid: "jwk-2")

        let jwk1 = try await generator.convertToJWK(keyPair: keyPair1)
        let jwk2 = try await generator.convertToJWK(keyPair: keyPair2)

        #expect(jwk1.kid != jwk2.kid)
        #expect(jwk1.n != jwk2.n)
        #expect(jwk1.e == jwk2.e) // Exponent should be the same
    }

    @Test("JWK can be encoded to JSON")
    func jwkEncodesToJSON() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "json-test")
        let jwk = try await generator.convertToJWK(keyPair: keyPair)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(jwk)
        let jsonString = String(data: jsonData, encoding: .utf8)

        #expect(jsonString != nil)
        #expect(jsonString?.contains("\"kty\":\"RSA\"") == true)
        #expect(jsonString?.contains("\"use\":\"sig\"") == true)
        #expect(jsonString?.contains("\"kid\":\"json-test\"") == true)
        #expect(jsonString?.contains("\"alg\":\"RS256\"") == true)
    }

    @Test("JWK round-trip encoding/decoding")
    func jwkRoundTrip() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "roundtrip-test")
        let originalJWK = try await generator.convertToJWK(keyPair: keyPair)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalJWK)

        let decoder = JSONDecoder()
        let decodedJWK = try decoder.decode(RSAPublicJWK.self, from: jsonData)

        #expect(decodedJWK.kty == originalJWK.kty)
        #expect(decodedJWK.use == originalJWK.use)
        #expect(decodedJWK.kid == originalJWK.kid)
        #expect(decodedJWK.alg == originalJWK.alg)
        #expect(decodedJWK.n == originalJWK.n)
        #expect(decodedJWK.e == originalJWK.e)
    }

    // MARK: - Edge Cases

    @Test("Generate key pair with empty kid")
    func generateKeyPairWithEmptyKid() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "")

        #expect(keyPair.kid == "")
        #expect(!keyPair.privateKeyPEM.isEmpty)
        #expect(!keyPair.publicKeyPEM.isEmpty)
    }

    @Test("Generate key pair with special characters in kid")
    func generateKeyPairWithSpecialCharacters() async throws {
        let generator = KeyGenerator()
        let kid = "key-2024-01-01_v1.2.3"
        let keyPair = try await generator.generateKeyPair(kid: kid)

        #expect(keyPair.kid == kid)
    }

    @Test("Generate key pair with very long kid")
    func generateKeyPairWithLongKid() async throws {
        let generator = KeyGenerator()
        let kid = String(repeating: "a", count: 256)
        let keyPair = try await generator.generateKeyPair(kid: kid)

        #expect(keyPair.kid == kid)
    }

    @Test("Generate many key pairs sequentially")
    func generateManyKeyPairs() async throws {
        let generator = KeyGenerator()
        var keyPairs: [KeyGenerator.RSAKeyPair] = []

        for i in 0..<5 {
            let keyPair = try await generator.generateKeyPair(kid: "key-\(i)")
            keyPairs.append(keyPair)
        }

        #expect(keyPairs.count == 5)

        // All should be unique
        let uniqueKids = Set(keyPairs.map { $0.kid })
        #expect(uniqueKids.count == 5)

        let uniquePrivateKeys = Set(keyPairs.map { $0.privateKeyPEM })
        #expect(uniquePrivateKeys.count == 5)
    }

    // MARK: - Signing and Verification Tests

    @Test("Generated key can sign JWT payload")
    func generatedKeyCanSignJWT() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "sign-test")

        // Create a test payload
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

        // Load the private key and sign
        let rsaKey = try RSAKey.private(pem: keyPair.privateKeyPEM)
        let signer = JWTSigner.rs256(key: rsaKey)
        let signers = JWTSigners()
        signers.use(signer, kid: JWKIdentifier(string: keyPair.kid), isDefault: true)

        let token = try signers.sign(payload, kid: JWKIdentifier(string: keyPair.kid))

        #expect(!token.isEmpty)
        #expect(token.split(separator: ".").count == 3)
    }

    @Test("Generated key can verify signed JWT")
    func generatedKeyCanVerifyJWT() async throws {
        let generator = KeyGenerator()
        let keyPair = try await generator.generateKeyPair(kid: "verify-test")

        let payload = Payload(
            issuer: IssuerClaim(value: "https://test.example.com"),
            subject: SubjectClaim(value: "verify@example.com"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "test-tenant",
            role: "user",
            user: "verify@example.com"
        )

        // Sign with private key
        let privateKey = try RSAKey.private(pem: keyPair.privateKeyPEM)
        let signer = JWTSigner.rs256(key: privateKey)
        let signers = JWTSigners()
        signers.use(signer, kid: JWKIdentifier(string: keyPair.kid), isDefault: true)
        let token = try signers.sign(payload, kid: JWKIdentifier(string: keyPair.kid))

        // Verify with public key
        let publicKey = try RSAKey.public(pem: keyPair.publicKeyPEM)
        let verifier = JWTSigner.rs256(key: publicKey)
        let verifiers = JWTSigners()
        verifiers.use(verifier, kid: JWKIdentifier(string: keyPair.kid), isDefault: true)

        let verified = try verifiers.verify(token, as: Payload.self)
        #expect(verified.subject.value == "verify@example.com")
        #expect(verified.tenant == "test-tenant")
    }
}
