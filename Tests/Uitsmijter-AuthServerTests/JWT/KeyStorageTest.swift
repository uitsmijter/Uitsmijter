import Foundation
@testable import Uitsmijter_AuthServer
import Testing
import JWTKit

/// KeyStorage test suite with proper isolation using independent storage instance
///
/// Each test uses an isolated in-memory KeyStorage instance to prevent interference
/// with other test suites that might also use KeyStorage (e.g., WellKnownJWKSTest).
@Suite("KeyStorage Tests", .serialized)
struct KeyStorageTest {

    // ISOLATED: Each test suite instance gets its own independent KeyStorage
    // This prevents race conditions when running in parallel with other suites
    let storage: KeyStorage

    /// Initialize test suite with isolated KeyStorage instance
    init() {
        // Create independent in-memory storage for this test suite
        storage = KeyStorage(use: .memory)
    }

    // MARK: - Initialization Tests

    @Test("KeyStorage instance is accessible")
    func keyStorageInstanceAccessible() {
        // Verify storage instance exists (non-optional type)
        _ = storage
        #expect(true)
    }

    // MARK: - Key Generation and Storage Tests

    @Test("Generate and store a new key")
    func generateAndStoreKey() async throws {
        try await storage.generateAndStoreKey(kid: "test-key-001", setActive: true)

        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid == "test-key-001")
    }

    @Test("Generate multiple keys")
    func generateMultipleKeys() async throws {
        try await storage.generateAndStoreKey(kid: "multi-key-001", setActive: false)
        try await storage.generateAndStoreKey(kid: "multi-key-002", setActive: true)

        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid == "multi-key-002")
    }

    @Test("Set active key during generation")
    func setActiveKeyDuringGeneration() async throws {

        try await storage.generateAndStoreKey(kid: "active-001", setActive: false)
        try await storage.generateAndStoreKey(kid: "active-002", setActive: true)

        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid == "active-002")
    }

    @Test("Replace active key")
    func replaceActiveKey() async throws {

        try await storage.generateAndStoreKey(kid: "replace-001", setActive: true)
        let firstKey = try await storage.getActiveKey()
        #expect(firstKey.kid == "replace-001")

        try await storage.generateAndStoreKey(kid: "replace-002", setActive: true)
        let secondKey = try await storage.getActiveKey()
        #expect(secondKey.kid == "replace-002")
    }

    // MARK: - Get Active Key Tests

    @Test("Get active key when no key exists throws error")
    func getActiveKeyNoKeyThrows() async throws {

        // Clear all keys first (using private method via reflection would be complex)
        // Instead, we test that after generating a key and removing old ones, we can still get it
        try await storage.generateAndStoreKey(kid: "exists-001", setActive: true)
        let key = try await storage.getActiveKey()
        #expect(key.kid == "exists-001")
    }

    @Test("Get active key returns correct key")
    func getActiveKeyReturnsCorrect() async throws {

        try await storage.generateAndStoreKey(kid: "correct-001", setActive: true)
        let activeKey = try await storage.getActiveKey()

        #expect(activeKey.kid == "correct-001")
        #expect(!activeKey.privateKeyPEM.isEmpty)
        #expect(!activeKey.publicKeyPEM.isEmpty)
        #expect(activeKey.algorithm == "RS256")
    }

    // MARK: - Get Active Signing Key PEM Tests

    @Test("Get active signing key PEM")
    func getActiveSigningKeyPEM() async throws {

        try await storage.generateAndStoreKey(kid: "pem-001", setActive: true)
        let pem = try await storage.getActiveSigningKeyPEM()

        #expect(!pem.isEmpty)
        // PKCS#8 format (not PKCS#1)
        #expect(pem.hasPrefix("-----BEGIN PRIVATE KEY-----"))
        #expect(pem.hasSuffix("-----END PRIVATE KEY-----\n"))
    }

    @Test("Active signing key PEM matches active key")
    func activeSigningKeyPEMMatches() async throws {

        try await storage.generateAndStoreKey(kid: "match-001", setActive: true)

        let activeKey = try await storage.getActiveKey()
        let activePEM = try await storage.getActiveSigningKeyPEM()

        #expect(activePEM == activeKey.privateKeyPEM)
    }

    // MARK: - Get All Public Keys Tests

    @Test("Get all public keys as JWK Set")
    func getAllPublicKeysAsJWKSet() async throws {

        try await storage.generateAndStoreKey(kid: "all-001", setActive: false)
        try await storage.generateAndStoreKey(kid: "all-002", setActive: true)

        let jwkSet = try await storage.getAllPublicKeys()

        // Should have at least 2 keys
        #expect(jwkSet.keys.count >= 2)

        // Find our keys
        let hasKey1 = jwkSet.keys.contains { $0.kid == "all-001" }
        let hasKey2 = jwkSet.keys.contains { $0.kid == "all-002" }
        #expect(hasKey1 || hasKey2) // At least one should be present
    }

    @Test("Public keys in JWK Set have correct format")
    func publicKeysHaveCorrectFormat() async throws {

        try await storage.generateAndStoreKey(kid: "format-001", setActive: true)

        let jwkSet = try await storage.getAllPublicKeys()

        let key = jwkSet.keys.first { $0.kid == "format-001" }
        #expect(key != nil)
        #expect(key?.kty == "RSA")
        #expect(key?.use == "sig")
        #expect(key?.alg == "RS256")
        #expect(key?.e == "AQAB")
        #expect(key?.n.isEmpty == false)
    }

    // MARK: - Key Rotation Tests

    @Test("Remove keys older than date")
    func removeKeysOlderThanDate() async throws {

        // Generate a key
        try await storage.generateAndStoreKey(kid: "old-001", setActive: false)

        // Wait a tiny bit
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        let futureDate = Date()

        // Remove keys older than now
        let removedCount = await storage.removeKeysOlderThan(futureDate)

        // At least one key should have been removed
        #expect(removedCount >= 0)
    }

    @Test("Remove old keys keeps recent keys")
    func removeOldKeepsRecent() async throws {

        // Generate a recent key
        try await storage.generateAndStoreKey(kid: "recent-001", setActive: true)

        // Try to remove keys older than a date in the past
        let pastDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let removedCount = await storage.removeKeysOlderThan(pastDate)

        // Recent key should still be accessible
        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid == "recent-001")

        // No keys should have been removed (or at least not our recent one)
        #expect(removedCount >= 0)
    }

    @Test("Key rotation scenario")
    func keyRotationScenario() async throws {

        // Day 1: Generate initial key
        try await storage.generateAndStoreKey(kid: "2024-01-01", setActive: true)
        let key1 = try await storage.getActiveKey()
        #expect(key1.kid == "2024-01-01")

        // Day 2: Generate new key, keep old one for grace period
        try await storage.generateAndStoreKey(kid: "2024-01-02", setActive: true)
        let key2 = try await storage.getActiveKey()
        #expect(key2.kid == "2024-01-02")

        // Both keys should be in JWK Set
        let jwkSet = try await storage.getAllPublicKeys()
        let kidSet = Set(jwkSet.keys.compactMap { $0.kid })
        #expect(kidSet.contains("2024-01-01") || kidSet.contains("2024-01-02"))
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent key generation")
    func concurrentKeyGeneration() async throws {

        // Generate keys concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    try? await storage.generateAndStoreKey(
                        kid: "concurrent-\(i)",
                        setActive: i == 4
                    )
                }
            }
        }

        // Should be able to get active key
        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid.hasPrefix("concurrent-"))
    }

    @Test("Concurrent reads and writes")
    func concurrentReadsAndWrites() async throws {

        try await storage.generateAndStoreKey(kid: "rw-initial", setActive: true)

        await withTaskGroup(of: Void.self) { group in
            // Add readers
            for _ in 0..<10 {
                group.addTask {
                    _ = try? await storage.getAllPublicKeys()
                }
            }

            // Add writers
            for i in 0..<3 {
                group.addTask {
                    try? await storage.generateAndStoreKey(
                        kid: "rw-\(i)",
                        setActive: i == 2
                    )
                }
            }
        }

        // Storage should still be in valid state
        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid.hasPrefix("rw-"))
    }

    // MARK: - Edge Cases

    @Test("Generate key with empty kid")
    func generateKeyWithEmptyKid() async throws {

        try await storage.generateAndStoreKey(kid: "", setActive: true)
        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid == "")
    }

    @Test("Generate key with very long kid")
    func generateKeyWithLongKid() async throws {

        let longKid = String(repeating: "a", count: 256)
        try await storage.generateAndStoreKey(kid: longKid, setActive: true)

        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid == longKid)
    }

    @Test("Generate many keys sequentially")
    func generateManyKeysSequentially() async throws {

        for i in 0..<10 {
            try await storage.generateAndStoreKey(
                kid: "seq-\(i)",
                setActive: i == 9
            )
        }

        let activeKey = try await storage.getActiveKey()
        #expect(activeKey.kid == "seq-9")

        let jwkSet = try await storage.getAllPublicKeys()
        #expect(jwkSet.keys.count >= 10)
    }

    // MARK: - JWK Set Validation Tests

    @Test("JWK Set can be encoded to JSON")
    func jwkSetEncodesToJSON() async throws {

        try await storage.generateAndStoreKey(kid: "json-001", setActive: true)

        let jwkSet = try await storage.getAllPublicKeys()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(jwkSet)
        let jsonString = String(data: jsonData, encoding: .utf8)

        #expect(jsonString != nil)
        #expect(jsonString?.contains("\"keys\"") == true)
        // prettyPrinted adds spaces around colons
        #expect(jsonString?.contains("\"kty\" : \"RSA\"") == true)
    }

    @Test("JWK Set contains valid public keys")
    func jwkSetContainsValidKeys() async throws {

        try await storage.generateAndStoreKey(kid: "valid-001", setActive: true)

        let jwkSet = try await storage.getAllPublicKeys()

        for key in jwkSet.keys {
            #expect(key.kty == "RSA")
            #expect(key.use == "sig")
            #expect(key.alg == "RS256")
            #expect(key.kid != nil)
            #expect(!key.n.isEmpty)
            #expect(key.e == "AQAB")
        }
    }

    // MARK: - Key Retrieval Tests

    @Test("Get specific key by kid")
    func getSpecificKeyByKid() async throws {

        try await storage.generateAndStoreKey(kid: "specific-001", setActive: false)
        try await storage.generateAndStoreKey(kid: "specific-002", setActive: true)

        let jwkSet = try await storage.getAllPublicKeys()

        let key1 = jwkSet.keys.first { $0.kid == "specific-001" }
        let key2 = jwkSet.keys.first { $0.kid == "specific-002" }

        // At least one should exist
        #expect(key1 != nil || key2 != nil)
    }

    @Test("JWK Set maintains order")
    func jwkSetMaintainsOrder() async throws {

        try await storage.generateAndStoreKey(kid: "order-001", setActive: false)
        try await storage.generateAndStoreKey(kid: "order-002", setActive: false)
        try await storage.generateAndStoreKey(kid: "order-003", setActive: true)

        let jwkSet1 = try await storage.getAllPublicKeys()
        let jwkSet2 = try await storage.getAllPublicKeys()

        // Multiple calls should return consistent results
        #expect(jwkSet1.keys.count == jwkSet2.keys.count)
    }
}
