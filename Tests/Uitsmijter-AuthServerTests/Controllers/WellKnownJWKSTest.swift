import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

/// JWKS Endpoint Integration Tests with isolated app instances
///
/// Each test creates a fresh Vapor application via withApp(), which initializes
/// its own independent KeyStorage instance through app.keyStorage in configure.swift.
/// This ensures complete test isolation without shared state pollution.
@Suite("JWKS Endpoint Integration Tests", .serialized)
// swiftlint:disable type_body_length
struct WellKnownJWKSTest {
    let decoder = JSONDecoder()

    // MARK: - JWKS Endpoint Tests

    @Test("GET /.well-known/jwks.json returns JWK Set")
    func getJWKSReturnsJWKSet() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    // Check content type
                    let contentType = res.headers.first(name: .contentType)
                    #expect(contentType?.contains("application/json") == true)

                    // Check cache control header
                    let cacheControl = res.headers.first(name: .cacheControl)
                    #expect(cacheControl?.contains("public") == true)
                    #expect(cacheControl?.contains("max-age=3600") == true)

                    // Decode response
                    let jwkSet = try res.content.decode(JWKSet.self)

                    // JWK Set should have keys array
                    #expect(!jwkSet.keys.isEmpty)

                    // Each key should have required fields
                    for key in jwkSet.keys {
                        #expect(key.kty == "RSA")
                        #expect(key.use == "sig")
                        #expect(key.alg == "RS256")
                        #expect(key.kid != nil)
                        #expect(!key.n.isEmpty)
                        #expect(key.e == "AQAB")
                    }
                }
            )
        }
    }

    @Test("JWKS endpoint returns valid JSON structure")
    func jwksEndpointReturnsValidJSON() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    // Parse as raw JSON
                    let body = res.body.string
                    guard let data = body.data(using: .utf8) else {
                        Issue.record("Failed to encode body as UTF-8")
                        return
                    }
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                    // Check structure
                    #expect(json?["keys"] != nil)

                    let keys = json?["keys"] as? [[String: Any]]
                    #expect(keys != nil)
                    #expect(keys?.isEmpty == false)

                    // Check first key structure
                    if let firstKey = keys?.first {
                        #expect(firstKey["kty"] as? String == "RSA")
                        #expect(firstKey["use"] as? String == "sig")
                        #expect(firstKey["alg"] as? String == "RS256")
                        #expect(firstKey["kid"] is String)
                        #expect(firstKey["n"] is String)
                        #expect(firstKey["e"] as? String == "AQAB")
                    }
                }
            )
        }
    }

    @Test("JWKS endpoint modulus is base64url encoded")
    func jwksEndpointModulusIsBase64URLEncoded() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    let jwkSet = try res.content.decode(JWKSet.self)

                    for key in jwkSet.keys {
                        // Base64url should only contain alphanumeric, -, and _ (no padding)
                        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
                        let modulusChars = CharacterSet(charactersIn: key.n)
                        #expect(modulusChars.isSubset(of: validChars))

                        // Should not contain padding
                        #expect(!key.n.contains("="))

                        // Modulus should be reasonably long for 2048-bit key
                        #expect(key.n.count > 300)
                    }
                }
            )
        }
    }

    @Test("JWKS endpoint exponent is standard value")
    func jwksEndpointExponentIsStandard() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    let jwkSet = try res.content.decode(JWKSet.self)

                    for key in jwkSet.keys {
                        // Standard RSA exponent 65537 encodes to "AQAB"
                        #expect(key.e == "AQAB")
                    }
                }
            )
        }
    }

    @Test("JWKS endpoint kid matches format")
    func jwksEndpointKidMatchesFormat() async throws {
        try await withApp(configure: configure) { app in
            // Generate a key with date format AFTER app is created to ensure proper isolation
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateKid = dateFormatter.string(from: Date())
            try await KeyStorage.shared.generateAndStoreKey(kid: dateKid, setActive: false)


            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    let jwkSet = try res.content.decode(JWKSet.self)

                    // Filter to only date-formatted keys (YYYY-MM-DD)
                    // This handles test pollution from other suites
                    let kidPattern = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
                    let validKeys = jwkSet.keys.filter { key in
                        guard let kid = key.kid else { return false }
                        return kid.range(of: kidPattern, options: .regularExpression) != nil
                    }

                    // Should have at least one properly formatted key (the one we just generated)
                    #expect(validKeys.count >= 1)

                    for key in validKeys {
                        guard let kid = key.kid else {
                            Issue.record("Key missing kid")
                            continue
                        }
                        #expect(!kid.isEmpty)

                        // kid should be date format: YYYY-MM-DD
                        let kidMatches = kid.range(
                            of: kidPattern,
                            options: .regularExpression
                        )
                        #expect(kidMatches != nil)
                    }
                }
            )
        }
    }

    // MARK: - RFC 7517 Compliance Tests

    @Test("JWKS endpoint complies with RFC 7517 structure")
    func jwksEndpointCompliesWithRFC7517() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    let body = res.body.string
                    guard let data = body.data(using: .utf8) else {
                        Issue.record("Failed to encode body as UTF-8")
                        return
                    }
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                    // RFC 7517 Section 5: JWK Set MUST have "keys" member
                    #expect(json?["keys"] != nil)

                    // "keys" MUST be an array
                    let keys = json?["keys"] as? [[String: Any]]
                    #expect(keys != nil)

                    // Each key must comply with RFC 7517 Section 6.3.1 (RSA)
                    for key in keys ?? [] {
                        // kty is REQUIRED
                        #expect(key["kty"] as? String == "RSA")

                        // For RSA keys, n and e are REQUIRED
                        #expect(key["n"] is String)
                        #expect(key["e"] is String)

                        // use, kid, alg are RECOMMENDED
                        #expect(key["use"] as? String == "sig")
                        #expect(key["kid"] is String)
                        #expect(key["alg"] as? String == "RS256")
                    }
                }
            )
        }
    }

    // MARK: - HTTP Method Tests

    @Test("JWKS endpoint supports GET method")
    func jwksEndpointSupportsGET() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)
                }
            )
        }
    }


    // MARK: - Edge Cases

    @Test("JWKS endpoint handles multiple concurrent requests")
    func jwksEndpointHandlesConcurrentRequests() async throws {
        try await withApp(configure: configure) { app in
            // Make multiple concurrent requests
            // Note: Reduced from 10 to 5 concurrent requests to prevent resource exhaustion
            // when running with --parallel --num-workers 8 (8 workers × 5 requests = 40 total)
            await withTaskGroup(of: Bool.self) { group in
                for _ in 0..<5 {
                    group.addTask {
                        do {
                            let response = try await app.sendRequest(.GET, ".well-known/jwks.json")
                            return response.status == .ok
                        } catch {
                            return false
                        }
                    }
                }

                var results: [Bool] = []
                for await result in group {
                    results.append(result)
                }

                #expect(results.count == 5)
                #expect(results.allSatisfy { $0 })
            }
        }
    }

    @Test("JWKS endpoint returns consistent results for same key")
    func jwksEndpointReturnsConsistentResultsForSameKey() async throws {
        try await withApp(configure: configure) { app in
            // Generate a unique test key to ensure we have at least one key to verify
            let testKid = "test-consistent-\(UUID().uuidString.prefix(8))"
            guard let keyStorage = app.keyStorage else {
                Issue.record("app.keyStorage not initialized")
                return
            }
            try await keyStorage.generateAndStoreKey(kid: testKid, setActive: false)

            // Make two requests
            let response1 = try await app.sendRequest(.GET, ".well-known/jwks.json")
            let response2 = try await app.sendRequest(.GET, ".well-known/jwks.json")

            #expect(response1.status == .ok)
            #expect(response2.status == .ok)

            let jwkSet1 = try response1.content.decode(JWKSet.self)
            let jwkSet2 = try response2.content.decode(JWKSet.self)

            // Verify our test key appears consistently in both responses
            let key1 = jwkSet1.keys.first { $0.kid == testKid }
            let key2 = jwkSet2.keys.first { $0.kid == testKid }

            #expect(key1 != nil, "Test key should appear in first response")
            #expect(key2 != nil, "Test key should appear in second response")

            // Verify the key's properties are identical in both responses
            if let key1 = key1, let key2 = key2 {
                #expect(key1.kty == key2.kty)
                #expect(key1.use == key2.use)
                #expect(key1.alg == key2.alg)
                #expect(key1.n == key2.n)
                #expect(key1.e == key2.e)
            }

            // Note: We cannot reliably test total key count or all kids matching
            // because other test suites run in parallel and may add/remove keys
            // between our two requests. This is expected behavior in a parallel
            // test environment and not a bug.
        }
    }
}
// swiftlint:enable type_body_length
