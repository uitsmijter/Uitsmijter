import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@Suite("JWK Data Model Tests")
// swiftlint:disable type_body_length
struct JWKTest {

    // MARK: - RSAPublicJWK Tests

    @Test("Create RSAPublicJWK with all required fields")
    func createRSAPublicJWK() {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "2024-01-01",
            alg: "RS256",
            n: "test-modulus",
            e: "AQAB"
        )

        #expect(jwk.kty == "RSA")
        #expect(jwk.use == "sig")
        #expect(jwk.kid == "2024-01-01")
        #expect(jwk.alg == "RS256")
        #expect(jwk.n == "test-modulus")
        #expect(jwk.e == "AQAB")
    }

    @Test("Create RSAPublicJWK with optional fields nil")
    func createRSAPublicJWKWithNilOptionals() {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: nil,
            kid: nil,
            alg: nil,
            n: "test-modulus",
            e: "AQAB"
        )

        #expect(jwk.kty == "RSA")
        #expect(jwk.use == nil)
        #expect(jwk.kid == nil)
        #expect(jwk.alg == nil)
        #expect(jwk.n == "test-modulus")
        #expect(jwk.e == "AQAB")
    }

    @Test("RSAPublicJWK is Codable")
    func rsaPublicJWKIsCodable() throws {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "test-key",
            alg: "RS256",
            n: "modulus-value",
            e: "AQAB"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(jwk)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RSAPublicJWK.self, from: data)

        #expect(decoded.kty == jwk.kty)
        #expect(decoded.use == jwk.use)
        #expect(decoded.kid == jwk.kid)
        #expect(decoded.alg == jwk.alg)
        #expect(decoded.n == jwk.n)
        #expect(decoded.e == jwk.e)
    }

    @Test("RSAPublicJWK encodes to correct JSON structure")
    func rsaPublicJWKJSONStructure() throws {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "key-123",
            alg: "RS256",
            n: "test-n",
            e: "AQAB"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(jwk)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString?.contains("\"alg\":\"RS256\"") == true)
        #expect(jsonString?.contains("\"e\":\"AQAB\"") == true)
        #expect(jsonString?.contains("\"kid\":\"key-123\"") == true)
        #expect(jsonString?.contains("\"kty\":\"RSA\"") == true)
        #expect(jsonString?.contains("\"n\":\"test-n\"") == true)
        #expect(jsonString?.contains("\"use\":\"sig\"") == true)
    }

    @Test("RSAPublicJWK decodes from JSON")
    func rsaPublicJWKDecodesFromJSON() throws {
        let jsonString = """
        {
            "kty": "RSA",
            "use": "sig",
            "kid": "2024-01-01",
            "alg": "RS256",
            "n": "test-modulus-value",
            "e": "AQAB"
        }
        """

        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8) else {
            Issue.record("Failed to encode JSON string as UTF-8")
            return
        }
        let jwk = try decoder.decode(RSAPublicJWK.self, from: data)

        #expect(jwk.kty == "RSA")
        #expect(jwk.use == "sig")
        #expect(jwk.kid == "2024-01-01")
        #expect(jwk.alg == "RS256")
        #expect(jwk.n == "test-modulus-value")
        #expect(jwk.e == "AQAB")
    }

    @Test("RSAPublicJWK decodes with missing optional fields")
    func rsaPublicJWKDecodesWithMissingOptionals() throws {
        let jsonString = """
        {
            "kty": "RSA",
            "n": "modulus",
            "e": "AQAB"
        }
        """

        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8) else {
            Issue.record("Failed to encode JSON string as UTF-8")
            return
        }
        let jwk = try decoder.decode(RSAPublicJWK.self, from: data)

        #expect(jwk.kty == "RSA")
        #expect(jwk.use == nil)
        #expect(jwk.kid == nil)
        #expect(jwk.alg == nil)
        #expect(jwk.n == "modulus")
        #expect(jwk.e == "AQAB")
    }

    @Test("RSAPublicJWK is Sendable")
    func rsaPublicJWKIsSendable() {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "test",
            alg: "RS256",
            n: "n",
            e: "e"
        )

        // This should compile without warnings - Sendable conformance
        Task {
            _ = jwk
        }

        #expect(jwk.kty == "RSA")
    }

    // MARK: - JWKSet Tests

    @Test("Create JWKSet with single key")
    func createJWKSetWithSingleKey() {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "key-1",
            alg: "RS256",
            n: "modulus",
            e: "AQAB"
        )

        let jwkSet = JWKSet(key: jwk)

        #expect(jwkSet.keys.count == 1)
        #expect(jwkSet.keys[0].kid == "key-1")
    }

    @Test("Create JWKSet with multiple keys")
    func createJWKSetWithMultipleKeys() {
        let jwk1 = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "key-1",
            alg: "RS256",
            n: "modulus-1",
            e: "AQAB"
        )

        let jwk2 = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "key-2",
            alg: "RS256",
            n: "modulus-2",
            e: "AQAB"
        )

        let jwkSet = JWKSet(keys: [jwk1, jwk2])

        #expect(jwkSet.keys.count == 2)
        #expect(jwkSet.keys[0].kid == "key-1")
        #expect(jwkSet.keys[1].kid == "key-2")
    }

    @Test("Create JWKSet with empty keys array")
    func createJWKSetWithEmptyKeys() {
        let jwkSet = JWKSet(keys: [])

        #expect(jwkSet.keys.isEmpty)
    }

    @Test("JWKSet is Codable")
    func jwkSetIsCodable() throws {
        let jwk1 = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "key-1",
            alg: "RS256",
            n: "modulus-1",
            e: "AQAB"
        )

        let jwk2 = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "key-2",
            alg: "RS256",
            n: "modulus-2",
            e: "AQAB"
        )

        let jwkSet = JWKSet(keys: [jwk1, jwk2])

        let encoder = JSONEncoder()
        let data = try encoder.encode(jwkSet)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JWKSet.self, from: data)

        #expect(decoded.keys.count == 2)
        #expect(decoded.keys[0].kid == "key-1")
        #expect(decoded.keys[1].kid == "key-2")
    }

    @Test("JWKSet encodes to correct JSON structure")
    func jwkSetJSONStructure() throws {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "test-key",
            alg: "RS256",
            n: "modulus",
            e: "AQAB"
        )

        let jwkSet = JWKSet(key: jwk)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(jwkSet)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString?.contains("\"keys\"") == true)
        // prettyPrinted adds spaces around colons
        #expect(jsonString?.contains("\"kty\" : \"RSA\"") == true)
        #expect(jsonString?.contains("\"kid\" : \"test-key\"") == true)
    }

    @Test("JWKSet decodes from RFC 7517 example")
    func jwkSetDecodesFromRFCExample() throws {
        let jsonString = """
        {
          "keys": [
            {
              "kty": "RSA",
              "use": "sig",
              "kid": "2024-01-01",
              "alg": "RS256",
              "n": "test-modulus",
              "e": "AQAB"
            },
            {
              "kty": "RSA",
              "use": "sig",
              "kid": "2024-01-15",
              "alg": "RS256",
              "n": "another-modulus",
              "e": "AQAB"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8) else {
            Issue.record("Failed to encode JSON string as UTF-8")
            return
        }
        let jwkSet = try decoder.decode(JWKSet.self, from: data)

        #expect(jwkSet.keys.count == 2)
        #expect(jwkSet.keys[0].kid == "2024-01-01")
        #expect(jwkSet.keys[1].kid == "2024-01-15")
    }

    @Test("JWKSet is Sendable")
    func jwkSetIsSendable() {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "test",
            alg: "RS256",
            n: "n",
            e: "e"
        )

        let jwkSet = JWKSet(key: jwk)

        // This should compile without warnings - Sendable conformance
        Task {
            _ = jwkSet
        }

        #expect(jwkSet.keys.count == 1)
    }

    // MARK: - RFC 7517 Compliance Tests

    @Test("JWK includes all RFC 7517 required fields for RSA")
    func jwkIncludesRFC7517RequiredFields() {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "test",
            alg: "RS256",
            n: "modulus",
            e: "exponent"
        )

        // Required fields per RFC 7517 Section 6.3.1
        #expect(jwk.kty == "RSA")  // REQUIRED
        #expect(jwk.n == "modulus")  // REQUIRED for RSA
        #expect(jwk.e == "exponent")  // REQUIRED for RSA
    }

    @Test("JWK Set has correct structure per RFC 7517")
    func jwkSetHasRFC7517Structure() throws {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "test",
            alg: "RS256",
            n: "modulus",
            e: "AQAB"
        )

        let jwkSet = JWKSet(key: jwk)

        // JWK Set MUST have "keys" member per RFC 7517 Section 5
        let encoder = JSONEncoder()
        let data = try encoder.encode(jwkSet)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["keys"] != nil)

        // keys MUST be an array
        let keys = json?["keys"] as? [[String: Any]]
        #expect(keys != nil)
        #expect(keys?.count == 1)
    }

    // MARK: - Edge Cases

    @Test("JWK with very long modulus")
    func jwkWithLongModulus() throws {
        let longModulus = String(repeating: "a", count: 1000)
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "test",
            alg: "RS256",
            n: longModulus,
            e: "AQAB"
        )

        #expect(jwk.n.count == 1000)

        // Should still encode/decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(jwk)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RSAPublicJWK.self, from: data)
        #expect(decoded.n == longModulus)
    }

    @Test("JWK with special characters in kid")
    func jwkWithSpecialCharactersInKid() throws {
        let jwk = RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: "key-2024-01-01_v1.2.3",
            alg: "RS256",
            n: "modulus",
            e: "AQAB"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(jwk)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RSAPublicJWK.self, from: data)
        #expect(decoded.kid == "key-2024-01-01_v1.2.3")
    }

    @Test("JWKSet with many keys")
    func jwkSetWithManyKeys() throws {
        var keys: [RSAPublicJWK] = []

        for i in 0..<100 {
            let jwk = RSAPublicJWK(
                kty: "RSA",
                use: "sig",
                kid: "key-\(i)",
                alg: "RS256",
                n: "modulus-\(i)",
                e: "AQAB"
            )
            keys.append(jwk)
        }

        let jwkSet = JWKSet(keys: keys)
        #expect(jwkSet.keys.count == 100)

        // Should still encode/decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(jwkSet)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JWKSet.self, from: data)
        #expect(decoded.keys.count == 100)
    }
}
// swiftlint:enable type_body_length
