import Foundation
import JWTKit

/// Actor-based thread-safe in-memory storage for RSA key pairs
///
/// This implementation stores keys in memory and is suitable for:
/// - Development and testing environments
/// - Single-instance deployments
/// - Testing scenarios where Redis is not available
///
/// **Warning**: Keys are lost on restart. For production horizontal scaling, use `RedisKeyStorage`.
actor MemoryKeyStorage: KeyStorageProtocol {

    /// Stored key pair with metadata
    private struct StoredKey: Sendable {
        let keyPair: KeyGenerator.RSAKeyPair
        let createdAt: Date
        let isActive: Bool
    }

    /// Dictionary of keys indexed by kid
    private var keys: [String: StoredKey] = [:]

    /// The currently active key ID for signing
    private var activeKeyID: String?

    /// Key generator for RSA key pair generation
    /// - Note: Injected to allow isolated instances in tests, preventing cross-test contention
    private let generator: KeyGenerator

    /// Initialize in-memory key storage
    /// - Parameter generator: KeyGenerator instance to use. Defaults to shared singleton for production.
    init(generator: KeyGenerator = KeyGenerator.shared) {
        self.generator = generator
    }

    // MARK: - KeyStorageProtocol

    func generateAndStoreKey(kid: String, setActive: Bool = true) async throws {
        let keyPair = try await generator.generateKeyPair(kid: kid)

        keys[kid] = StoredKey(
            keyPair: keyPair,
            createdAt: Date(),
            isActive: setActive
        )

        if setActive {
            // Optimize: Pre-collect keys to deactivate before mutation
            // This reduces actor lock duration and prevents dictionary mutation issues
            let keysToDeactivate = keys.keys.filter { $0 != kid }

            // Deactivate all other keys in batch
            for otherKid in keysToDeactivate {
                if let storedKey = keys[otherKid] {
                    keys[otherKid] = StoredKey(
                        keyPair: storedKey.keyPair,
                        createdAt: storedKey.createdAt,
                        isActive: false
                    )
                }
            }
            activeKeyID = kid
        }
    }

    func getActiveKey() async throws -> KeyGenerator.RSAKeyPair {
        // If we have an active key, return it
        if let activeKid = activeKeyID, let storedKey = keys[activeKid] {
            return storedKey.keyPair
        }

        // No active key exists - generate one with current date as kid
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let kid = formatter.string(from: Date())

        try await generateAndStoreKey(kid: kid, setActive: true)

        guard let storedKey = keys[kid] else {
            throw KeyStorageError.noActiveKey
        }

        return storedKey.keyPair
    }

    func getKey(kid: String) async -> KeyGenerator.RSAKeyPair? {
        return keys[kid]?.keyPair
    }

    func getAllKeys() async -> [KeyGenerator.RSAKeyPair] {
        return keys.values.map { $0.keyPair }
    }

    func getAllPublicKeys() async throws -> JWKSet {
        // Extract all key pairs from actor context BEFORE any await calls
        // This prevents holding the MemoryKeyStorage actor lock during KeyGenerator calls
        let keyPairs = keys.values.map { $0.keyPair }

        // CRITICAL: Use batched conversion to prevent actor reentrancy deadlock
        // The batched method processes all keys in ONE KeyGenerator actor call,
        // preventing circular waits when multiple KeyStorage instances run concurrently
        return try await generator.convertToJWKSet(keyPairs)
    }

    func getActiveSigningKeyPEM() async throws -> String {
        let activeKeyPair = try await getActiveKey()
        return activeKeyPair.privateKeyPEM
    }

    func removeKey(kid: String) async {
        keys.removeValue(forKey: kid)
        if activeKeyID == kid {
            activeKeyID = nil
        }
    }

    @discardableResult
    func removeKeysOlderThan(_ date: Date) async -> Int {
        var removedCount = 0

        for (kid, storedKey) in keys {
            // Don't remove the active key
            guard kid != activeKeyID else { continue }

            if storedKey.createdAt < date {
                keys.removeValue(forKey: kid)
                removedCount += 1
            }
        }

        return removedCount
    }

    func getKeyMetadata(kid: String) async -> (kid: String, createdAt: Date, isActive: Bool)? {
        guard let storedKey = keys[kid] else { return nil }
        return (kid: kid, createdAt: storedKey.createdAt, isActive: storedKey.isActive)
    }

    func getAllKeyMetadata() async -> [(kid: String, createdAt: Date, isActive: Bool)] {
        return keys.map { kid, storedKey in
            (kid: kid, createdAt: storedKey.createdAt, isActive: storedKey.isActive)
        }
    }

    func isHealthy() async -> Bool {
        // In-memory storage is always healthy (no external dependencies)
        return true
    }

    /// Remove all keys from storage (useful for testing)
    func removeAllKeys() async {
        keys.removeAll()
        activeKeyID = nil
    }
}
