import Foundation
import JWTKit

/// Thread-safe storage for RSA key pairs with rotation support
///
/// Manages the lifecycle of RSA keys used for JWT signing, including generation,
/// storage, and rotation. Keys are identified by their Key ID (kid), typically
/// formatted as ISO 8601 dates (e.g., "2025-01-08").
///
/// ## Key Rotation
///
/// The storage maintains multiple active keys to support gradual rotation:
/// - New keys can be added without invalidating existing JWTs
/// - Old keys remain available for verification
/// - The "active" key is used for new JWT signatures
///
/// ## Usage
///
/// ```swift
/// let storage = KeyStorage.shared
///
/// // Generate and store a new key
/// try await storage.generateAndStoreKey(kid: "2025-01-08")
///
/// // Get the current signing key
/// let activeKey = try await storage.getActiveKey()
///
/// // Get all public keys for JWKS endpoint
/// let jwks = try await storage.getAllPublicKeys()
/// ```
///
/// ## Thread Safety
///
/// This actor ensures thread-safe access to keys across concurrent requests.
///
/// - SeeAlso: ``KeyGenerator``
/// - SeeAlso: ``JWKSet``
actor KeyStorage {

    /// Shared singleton instance
    static let shared = KeyStorage()

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

    /// Key generator
    private let generator = KeyGenerator()

    /// Initialize key storage
    private init() {}

    /// Generate a new RSA key pair and store it
    ///
    /// Creates a new RSA key pair with the specified key ID and stores it.
    /// If `setActive` is true, this key becomes the active signing key.
    ///
    /// ## Key ID Format
    ///
    /// Recommended format: ISO 8601 date string (YYYY-MM-DD)
    /// ```swift
    /// let formatter = ISO8601DateFormatter()
    /// formatter.formatOptions = [.withFullDate]
    /// let kid = formatter.string(from: Date()) // "2025-01-08"
    /// ```
    ///
    /// - Parameters:
    ///   - kid: Unique key identifier
    ///   - setActive: Whether to set this key as the active signing key (default: true)
    /// - Throws: KeyGenerationError if key generation fails
    func generateAndStoreKey(kid: String, setActive: Bool = true) async throws {
        let keyPair = try await generator.generateKeyPair(kid: kid)

        keys[kid] = StoredKey(
            keyPair: keyPair,
            createdAt: Date(),
            isActive: setActive
        )

        if setActive {
            // Deactivate all other keys
            for (otherKid, storedKey) in keys where otherKid != kid {
                keys[otherKid] = StoredKey(
                    keyPair: storedKey.keyPair,
                    createdAt: storedKey.createdAt,
                    isActive: false
                )
            }
            activeKeyID = kid
        }
    }

    /// Get the active RSA key for signing
    ///
    /// Returns the currently active key pair, or generates a new one if no active key exists.
    ///
    /// - Returns: The active RSA key pair
    /// - Throws: KeyStorageError if no active key exists and generation fails
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

    /// Get an RSA key by kid
    ///
    /// Retrieves a specific key by its key ID. Used during JWT verification
    /// to match the kid in the JWT header.
    ///
    /// - Parameter kid: Key identifier
    /// - Returns: The key pair if found, nil otherwise
    func getKey(kid: String) async -> KeyGenerator.RSAKeyPair? {
        return keys[kid]?.keyPair
    }

    /// Get all stored keys
    ///
    /// Returns all key pairs currently in storage. Useful for exposing
    /// all public keys via the JWKS endpoint.
    ///
    /// - Returns: Array of all key pairs
    func getAllKeys() async -> [KeyGenerator.RSAKeyPair] {
        return keys.values.map { $0.keyPair }
    }

    /// Get all public keys as JWK Set
    ///
    /// Converts all stored keys to JWK format and returns them as a JWK Set
    /// suitable for the `/.well-known/jwks.json` endpoint.
    ///
    /// ## JWKS Endpoint Response
    ///
    /// The returned JWKSet can be directly encoded to JSON:
    /// ```swift
    /// let jwks = try await storage.getAllPublicKeys()
    /// return try JSONEncoder().encode(jwks)
    /// ```
    ///
    /// - Returns: JWK Set containing all public keys
    /// - Throws: ConversionError if JWK conversion fails
    func getAllPublicKeys() async throws -> JWKSet {
        var jwks: [RSAPublicJWK] = []

        for (_, storedKey) in keys {
            let jwk = try await generator.convertToJWK(keyPair: storedKey.keyPair)
            jwks.append(jwk)
        }

        return JWKSet(keys: jwks)
    }

    /// Get the active signing key PEM
    ///
    /// Returns the active private key in PEM format.
    /// Callers can create an RSAKey from this using `RSAKey.private(pem:)`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let pemString = try await storage.getActiveSigningKeyPEM()
    /// let rsaKey = try RSAKey.private(pem: pemString)
    /// ```
    ///
    /// - Returns: Private key PEM string
    /// - Throws: KeyStorageError if no active key exists
    func getActiveSigningKeyPEM() async throws -> String {
        let activeKeyPair = try await getActiveKey()
        return activeKeyPair.privateKeyPEM
    }

    /// Remove a key from storage
    ///
    /// Removes the key with the specified kid. If this was the active key,
    /// the active key ID is cleared (a new one will be generated on next access).
    ///
    /// ## Warning
    ///
    /// Removing keys may invalidate existing JWTs that were signed with those keys.
    /// Only remove keys after all JWTs signed with them have expired.
    ///
    /// - Parameter kid: Key identifier to remove
    func removeKey(kid: String) async {
        keys.removeValue(forKey: kid)
        if activeKeyID == kid {
            activeKeyID = nil
        }
    }

    /// Remove all keys older than the specified date
    ///
    /// Cleans up old keys to prevent unlimited growth of the key store.
    /// Does not remove the active key.
    ///
    /// ## Recommended Schedule
    ///
    /// Run this periodically (e.g., daily) to remove keys older than your
    /// maximum JWT expiration time plus a safety buffer:
    /// ```swift
    /// // Remove keys older than 90 days
    /// let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
    /// await storage.removeKeysOlderThan(cutoffDate)
    /// ```
    ///
    /// - Parameter date: Cutoff date - keys created before this will be removed
    /// - Returns: Number of keys removed
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

    /// Get key metadata
    ///
    /// Returns information about a stored key without exposing the key material.
    ///
    /// - Parameter kid: Key identifier
    /// - Returns: Key metadata (kid, creation date, active status)
    func getKeyMetadata(kid: String) async -> (kid: String, createdAt: Date, isActive: Bool)? {
        guard let storedKey = keys[kid] else { return nil }
        return (kid: kid, createdAt: storedKey.createdAt, isActive: storedKey.isActive)
    }

    /// Get all key metadata
    ///
    /// Returns metadata for all stored keys. Useful for administrative
    /// interfaces and monitoring.
    ///
    /// - Returns: Array of key metadata
    func getAllKeyMetadata() async -> [(kid: String, createdAt: Date, isActive: Bool)] {
        return keys.map { kid, storedKey in
            (kid: kid, createdAt: storedKey.createdAt, isActive: storedKey.isActive)
        }
    }
}

/// Key storage errors
enum KeyStorageError: Error, CustomStringConvertible {
    case noActiveKey
    case keyNotFound(String)
    case keyAlreadyExists(String)

    var description: String {
        switch self {
        case .noActiveKey:
            return "No active signing key available"
        case .keyNotFound(let kid):
            return "Key not found: \(kid)"
        case .keyAlreadyExists(let kid):
            return "Key already exists: \(kid)"
        }
    }
}
