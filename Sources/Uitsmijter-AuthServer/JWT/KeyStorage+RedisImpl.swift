import Foundation
@preconcurrency import Redis
import Logger
import JWTKit

/// Actor-based thread-safe Redis storage for RSA key pairs
///
/// This implementation stores keys in Redis and is suitable for:
/// - Production deployments with horizontal pod autoscaling
/// - Multi-instance deployments requiring consistent signing keys
/// - High-availability scenarios
///
/// ## Redis Schema
///
/// ```
/// uitsmijter:jwks:active -> kid (string)
/// uitsmijter:jwks:keys:{kid}:metadata -> JSON {"kid": "...", "createdAt": "...", "isActive": bool}
/// uitsmijter:jwks:keys:{kid}:private -> PEM private key
/// uitsmijter:jwks:keys:{kid}:public -> PEM public key
/// uitsmijter:jwks:index -> sorted set (score: timestamp, member: kid)
/// ```
///
/// ## Key Generation Strategy
///
/// - Only generates a new key if no key exists in Redis
/// - If active key is older than MAX_KEY_AGE_DAYS, generates a new key
/// - Uses distributed locking to prevent race conditions across pods
///
/// ## Thread Safety
///
/// Actor isolation ensures thread-safe access across concurrent requests within a single pod.
/// Redis provides consistency across multiple pods.
actor RedisKeyStorage: KeyStorageProtocol {

    /// Maximum age of active key before rotation (in days)
    private static let maxKeyAgeDays = 90

    /// Injected Redis client
    let redis: RedisClient

    /// Key generator
    private let generator = KeyGenerator()

    /// Redis key prefix
    private static let keyPrefix = "uitsmijter:jwks"

    init(_ client: RedisClient) {
        redis = client
    }

    // MARK: - KeyStorageProtocol

    func generateAndStoreKey(kid: String, setActive: Bool = true) async throws {
        let keyPair = try await generator.generateKeyPair(kid: kid)
        let createdAt = Date()

        // Store key metadata
        let metadata = KeyMetadata(kid: kid, createdAt: createdAt, isActive: setActive)
        let metadataData = try JSONEncoder.main.encode(metadata)
        guard let metadataString = String(data: metadataData, encoding: .utf8) else {
            throw KeyStorageError.encodingFailed
        }

        let metadataKey = try redisKey("\(Self.keyPrefix):keys:\(kid):metadata")
        let privateKey = try redisKey("\(Self.keyPrefix):keys:\(kid):private")
        let publicKey = try redisKey("\(Self.keyPrefix):keys:\(kid):public")

        // Store in Redis
        try await redis.set(metadataKey, to: metadataString).get()
        try await redis.set(privateKey, to: keyPair.privateKeyPEM).get()
        try await redis.set(publicKey, to: keyPair.publicKeyPEM).get()

        // Add to index (sorted set with timestamp as score)
        let indexKey = try redisKey("\(Self.keyPrefix):index")
        let timestamp = createdAt.timeIntervalSince1970
        _ = try await redis.zadd((kid, timestamp), to: indexKey).get()

        if setActive {
            // Set as active key
            let activeKey = try redisKey("\(Self.keyPrefix):active")
            try await redis.set(activeKey, to: kid).get()

            // Deactivate all other keys
            try await deactivateOtherKeys(except: kid)
        }
    }

    func getActiveKey() async throws -> KeyGenerator.RSAKeyPair {
        // Get active key ID from Redis
        let activeKey = try redisKey("\(Self.keyPrefix):active")
        guard let activeKidValue = try? await redis.get(activeKey).get(),
              let activeKid = activeKidValue.string else {
            // No active key exists - generate one
            return try await generateNewActiveKey()
        }

        // Fetch the key from Redis
        if let keyPair = try await fetchKey(kid: activeKid) {
            // Check if key is too old
            if let metadata = try await fetchMetadata(kid: activeKid) {
                let keyAge = Date().timeIntervalSince(metadata.createdAt) / (60 * 60 * 24)
                if keyAge > Double(Self.maxKeyAgeDays) {
                    Log.info(
                        "Active key \(activeKid) is \(Int(keyAge)) days old (max: \(Self.maxKeyAgeDays)), " +
                        "generating new key"
                    )
                    return try await generateNewActiveKey()
                }
            }
            return keyPair
        }

        // Active key reference exists but key data is missing - generate new one
        Log.warning("Active key reference exists (\(activeKid)) but key data is missing, generating new key")
        return try await generateNewActiveKey()
    }

    func getKey(kid: String) async -> KeyGenerator.RSAKeyPair? {
        return try? await fetchKey(kid: kid)
    }

    func getAllKeys() async -> [KeyGenerator.RSAKeyPair] {
        do {
            let kids = try await getAllKids()
            var keyPairs: [KeyGenerator.RSAKeyPair] = []

            for kid in kids {
                if let keyPair = try await fetchKey(kid: kid) {
                    keyPairs.append(keyPair)
                }
            }

            return keyPairs
        } catch {
            Log.error("Failed to get all keys from Redis: \(error)")
            return []
        }
    }

    func getAllPublicKeys() async throws -> JWKSet {
        // Extract all key pairs from actor context first
        let keyPairs = await getAllKeys()

        // Use batched conversion to avoid cross-actor deadlock
        // Single actor call prevents reentrancy issues under parallel load
        return try await generator.convertToJWKSet(keyPairs)
    }

    func getActiveSigningKeyPEM() async throws -> String {
        let activeKeyPair = try await getActiveKey()
        return activeKeyPair.privateKeyPEM
    }

    func removeKey(kid: String) async {
        do {
            let metadataKey = try redisKey("\(Self.keyPrefix):keys:\(kid):metadata")
            let privateKey = try redisKey("\(Self.keyPrefix):keys:\(kid):private")
            let publicKey = try redisKey("\(Self.keyPrefix):keys:\(kid):public")
            let indexKey = try redisKey("\(Self.keyPrefix):index")

            _ = try? await redis.delete([metadataKey, privateKey, publicKey]).get()
            _ = try? await redis.zrem(kid, from: indexKey).get()

            // If this was the active key, clear the active key reference
            let activeKey = try redisKey("\(Self.keyPrefix):active")
            let activeValue = try? await redis.get(activeKey).get()
            if let activeKid = activeValue?.string, activeKid == kid {
                _ = try? await redis.delete([activeKey]).get()
            }
        } catch {
            Log.error("Failed to remove key \(kid): \(error)")
        }
    }

    @discardableResult
    func removeKeysOlderThan(_ date: Date) async -> Int {
        do {
            let indexKey = try redisKey("\(Self.keyPrefix):index")
            let timestamp = date.timeIntervalSince1970

            // Get all kids older than the cutoff date
            let result = try await redis.zrangebyscore(
                from: indexKey,
                withScores: 0...timestamp
            ).get()

            var removedCount = 0
            let activeValue = try? await redis.get(try redisKey("\(Self.keyPrefix):active")).get()
            let activeKid = activeValue?.string

            for value in result {
                if let kid = value.string, kid != activeKid {
                    await removeKey(kid: kid)
                    removedCount += 1
                }
            }

            return removedCount
        } catch {
            Log.error("Failed to remove old keys: \(error)")
            return 0
        }
    }

    func getKeyMetadata(kid: String) async -> (kid: String, createdAt: Date, isActive: Bool)? {
        guard let metadata = try? await fetchMetadata(kid: kid) else {
            return nil
        }
        return (kid: metadata.kid, createdAt: metadata.createdAt, isActive: metadata.isActive)
    }

    func getAllKeyMetadata() async -> [(kid: String, createdAt: Date, isActive: Bool)] {
        do {
            let kids = try await getAllKids()
            var metadataList: [(kid: String, createdAt: Date, isActive: Bool)] = []

            for kid in kids {
                if let metadata = try await fetchMetadata(kid: kid) {
                    metadataList.append((kid: metadata.kid, createdAt: metadata.createdAt, isActive: metadata.isActive))
                }
            }

            return metadataList
        } catch {
            Log.error("Failed to get all key metadata: \(error)")
            return []
        }
    }

    func isHealthy() async -> Bool {
        do {
            _ = try await redis.ping().get()
            return true
        } catch {
            Log.error("Redis health check failed: \(error)")
            return false
        }
    }

    // MARK: - Private Helper Methods

    /// Generate a new active key with current date as kid
    private func generateNewActiveKey() async throws -> KeyGenerator.RSAKeyPair {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let kid = formatter.string(from: Date())

        try await generateAndStoreKey(kid: kid, setActive: true)

        guard let keyPair = try await fetchKey(kid: kid) else {
            throw KeyStorageError.noActiveKey
        }

        return keyPair
    }

    /// Fetch a key pair from Redis
    private func fetchKey(kid: String) async throws -> KeyGenerator.RSAKeyPair? {
        let privateKeyKey = try redisKey("\(Self.keyPrefix):keys:\(kid):private")
        let publicKeyKey = try redisKey("\(Self.keyPrefix):keys:\(kid):public")

        let privateValue = try? await redis.get(privateKeyKey).get()
        let publicValue = try? await redis.get(publicKeyKey).get()

        guard let privatePEM = privateValue?.string,
              let publicPEM = publicValue?.string else {
            return nil
        }

        return KeyGenerator.RSAKeyPair(
            privateKeyPEM: privatePEM,
            publicKeyPEM: publicPEM,
            kid: kid
        )
    }

    /// Fetch metadata for a key
    private func fetchMetadata(kid: String) async throws -> KeyMetadata? {
        let metadataKey = try redisKey("\(Self.keyPrefix):keys:\(kid):metadata")

        guard let value = try? await redis.get(metadataKey).get(),
              let metadataString = value.string,
              let metadataData = metadataString.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder.main.decode(KeyMetadata.self, from: metadataData)
    }

    /// Get all key IDs from the index
    private func getAllKids() async throws -> [String] {
        let indexKey = try redisKey("\(Self.keyPrefix):index")

        let result = try await redis.zrange(
            from: indexKey,
            fromIndex: 0
        ).get()

        return result.compactMap { $0.string }
    }

    /// Deactivate all keys except the specified one
    private func deactivateOtherKeys(except activeKid: String) async throws {
        let kids = try await getAllKids()

        for kid in kids where kid != activeKid {
            if var metadata = try await fetchMetadata(kid: kid) {
                metadata.isActive = false
                let metadataData = try JSONEncoder.main.encode(metadata)
                if let metadataString = String(data: metadataData, encoding: .utf8) {
                    let metadataKey = try redisKey("\(Self.keyPrefix):keys:\(kid):metadata")
                    try await redis.set(metadataKey, to: metadataString).get()
                }
            }
        }
    }

    /// Remove all keys from storage (useful for testing)
    func removeAllKeys() async {
        // Get all key IDs
        let metadata = await getAllKeyMetadata()

        // Remove each key
        for (kid, _, _) in metadata {
            await removeKey(kid: kid)
        }

        // Clear the active key reference
        do {
            let activeKey = try redisKey("\(Self.keyPrefix):active")
            _ = try? await redis.delete(activeKey).get()
        } catch {
            // Ignore errors - key might not exist
        }
    }

    /// Helper to create a RedisKey safely
    private func redisKey(_ string: String) throws -> RedisKey {
        guard let key = RedisKey(rawValue: string) else {
            throw KeyStorageError.invalidRedisKey(string)
        }
        return key
    }
}

// MARK: - Supporting Types

/// Metadata for a stored key
private struct KeyMetadata: Codable, Sendable {
    let kid: String
    let createdAt: Date
    var isActive: Bool
}
