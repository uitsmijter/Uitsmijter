import Foundation

/// Protocol for storing and retrieving RSA key pairs for JWT signing
/// All implementations should be actors to ensure thread-safe access
protocol KeyStorageProtocol: Sendable {
    /// Generate and store a new RSA key pair
    /// - Parameters:
    ///   - kid: Key identifier (typically ISO 8601 date string)
    ///   - setActive: Whether to set this key as the active signing key
    /// - Throws: Error if key generation or storage fails
    func generateAndStoreKey(kid: String, setActive: Bool) async throws

    /// Get the currently active RSA key for signing
    /// - Returns: The active RSA key pair
    /// - Throws: Error if no active key exists
    func getActiveKey() async throws -> KeyGenerator.RSAKeyPair

    /// Get a specific RSA key by its kid
    /// - Parameter kid: Key identifier
    /// - Returns: The key pair if found, nil otherwise
    func getKey(kid: String) async -> KeyGenerator.RSAKeyPair?

    /// Get all stored RSA key pairs
    /// - Returns: Array of all key pairs
    func getAllKeys() async -> [KeyGenerator.RSAKeyPair]

    /// Get all public keys as a JWK Set
    /// - Returns: JWK Set containing all public keys
    /// - Throws: Error if conversion to JWK format fails
    func getAllPublicKeys() async throws -> JWKSet

    /// Get the active signing key in PEM format
    /// - Returns: Private key PEM string
    /// - Throws: Error if no active key exists
    func getActiveSigningKeyPEM() async throws -> String

    /// Remove a specific key from storage
    /// - Parameter kid: Key identifier to remove
    func removeKey(kid: String) async

    /// Remove all keys older than the specified date
    /// - Parameter date: Cutoff date - keys created before this will be removed
    /// - Returns: Number of keys removed
    @discardableResult
    func removeKeysOlderThan(_ date: Date) async -> Int

    /// Get metadata about a specific key
    /// - Parameter kid: Key identifier
    /// - Returns: Key metadata (kid, creation date, active status) if found
    func getKeyMetadata(kid: String) async -> (kid: String, createdAt: Date, isActive: Bool)?

    /// Get metadata for all stored keys
    /// - Returns: Array of key metadata
    func getAllKeyMetadata() async -> [(kid: String, createdAt: Date, isActive: Bool)]

    /// Check if the storage backend is healthy and operational
    /// - Returns: true if storage is healthy, false otherwise
    func isHealthy() async -> Bool
}
