import Foundation
import JWTKit
import Vapor

/// A facade that manages RSA key storage through pluggable backend implementations.
///
/// `KeyStorage` provides a unified interface for storing and retrieving RSA keys for JWT signing,
/// abstracting the underlying storage mechanism. It supports multiple backends including Redis (production),
/// in-memory storage (development/testing), and custom implementations.
///
/// ## Overview
///
/// The struct acts as a strategy pattern implementation, delegating all operations to a backend that conforms
/// to ``KeyStorageProtocol``. This design allows for flexible deployment configurations:
///
/// - **Production (HPA)**: Redis-backed persistent storage for horizontal pod autoscaling
/// - **Development/Testing**: Fast in-memory storage
/// - **Custom**: User-provided storage implementation
///
/// ## Thread Safety
///
/// All operations are async and thread-safe through Swift's concurrency model. The struct conforms to `Sendable`,
/// making it safe to pass across concurrency boundaries.
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
/// // Initialize with Redis backend (production)
/// let storage = KeyStorage(use: .redis(redisClient))
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
/// - SeeAlso: ``KeyStorageProtocol``
/// - SeeAlso: ``KeyGenerator``
/// - SeeAlso: ``JWKSet``
struct KeyStorage: KeyStorageProtocol, Sendable {

    /// Shared singleton instance using in-memory storage
    /// - Note: This is suitable for development and testing. For production use, configure via `Application.keyStorage`.
    static let shared = KeyStorage(use: .memory)

    /// The underlying storage implementation that handles actual data persistence.
    private let implementation: KeyStorageProtocol

    /// Creates a new key storage with the specified backend implementation.
    ///
    /// - Parameter use: The storage backend to use. See ``KeyStorageImplementations`` for available options.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Production: Redis storage
    /// let storage = KeyStorage(use: .redis(client))
    ///
    /// // Development: In-memory storage
    /// let storage = KeyStorage(use: .memory)
    ///
    /// // Custom: User-provided implementation
    /// let storage = KeyStorage(use: .custom(implementation: myStorage))
    /// ```
    init(use: KeyStorageImplementations) {
        switch use {
        case .redis(let client):
            implementation = RedisKeyStorage(client)
        case .memory:
            implementation = MemoryKeyStorage()
        case .custom(implementation: let customImplementation):
            implementation = customImplementation
        }
    }

    // MARK: - KeyStorageProtocol

    func generateAndStoreKey(kid: String, setActive: Bool = true) async throws {
        try await implementation.generateAndStoreKey(kid: kid, setActive: setActive)
    }

    func getActiveKey() async throws -> KeyGenerator.RSAKeyPair {
        return try await implementation.getActiveKey()
    }

    func getKey(kid: String) async -> KeyGenerator.RSAKeyPair? {
        return await implementation.getKey(kid: kid)
    }

    func getAllKeys() async -> [KeyGenerator.RSAKeyPair] {
        return await implementation.getAllKeys()
    }

    func getAllPublicKeys() async throws -> JWKSet {
        return try await implementation.getAllPublicKeys()
    }

    func getActiveSigningKeyPEM() async throws -> String {
        return try await implementation.getActiveSigningKeyPEM()
    }

    func removeKey(kid: String) async {
        await implementation.removeKey(kid: kid)
    }

    @discardableResult
    func removeKeysOlderThan(_ date: Date) async -> Int {
        return await implementation.removeKeysOlderThan(date)
    }

    func getKeyMetadata(kid: String) async -> (kid: String, createdAt: Date, isActive: Bool)? {
        return await implementation.getKeyMetadata(kid: kid)
    }

    func getAllKeyMetadata() async -> [(kid: String, createdAt: Date, isActive: Bool)] {
        return await implementation.getAllKeyMetadata()
    }

    func isHealthy() async -> Bool {
        return await implementation.isHealthy()
    }

    func removeAllKeys() async {
        await implementation.removeAllKeys()
    }
}

/// A storage key for registering ``KeyStorage`` in Vapor's application storage.
///
/// This key enables dependency injection of the key storage throughout
/// the Vapor application via the storage container pattern.
struct KeyStorageKey: StorageKey {
    typealias Value = KeyStorage
}

/// Vapor application extension providing access to key storage.
extension Application {
    /// The key storage instance for this application.
    ///
    /// This property provides centralized access to the configured storage backend
    /// throughout the Vapor application. It's set during application configuration
    /// based on environment settings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Configure in configure.swift
    /// if app.environment == .production {
    ///     app.keyStorage = KeyStorage(use: .redis(redisClient))
    /// } else {
    ///     app.keyStorage = KeyStorage(use: .memory)
    /// }
    ///
    /// // Access in route handlers
    /// func jwks(req: Request) async throws -> JWKSet {
    ///     let storage = req.application.keyStorage
    ///     return try await storage?.getAllPublicKeys() ?? JWKSet(keys: [])
    /// }
    /// ```
    var keyStorage: KeyStorage? {
        get {
            storage[KeyStorageKey.self]
        }
        set {
            storage[KeyStorageKey.self] = newValue
        }
    }
}

/// Key storage errors
enum KeyStorageError: Error, CustomStringConvertible {
    case noActiveKey
    case keyNotFound(String)
    case keyAlreadyExists(String)
    case encodingFailed
    case invalidRedisKey(String)
    case storageError(String)

    var description: String {
        switch self {
        case .noActiveKey:
            return "No active signing key available"
        case .keyNotFound(let kid):
            return "Key not found: \(kid)"
        case .keyAlreadyExists(let kid):
            return "Key already exists: \(kid)"
        case .encodingFailed:
            return "Failed to encode key metadata"
        case .invalidRedisKey(let key):
            return "Invalid Redis key: \(key)"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}
