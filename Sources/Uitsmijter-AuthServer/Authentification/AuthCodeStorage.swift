import Foundation
import Vapor
@preconcurrency import Redis
import Logger

/// A facade that manages authorization code session storage through pluggable backend implementations.
///
/// `AuthCodeStorage` provides a unified interface for storing and retrieving OAuth2 authorization sessions,
/// abstracting the underlying storage mechanism. It supports multiple backends including Redis (production),
/// in-memory storage (development/testing), and custom implementations.
///
/// ## Overview
///
/// The struct acts as a strategy pattern implementation, delegating all operations to a backend that conforms
/// to ``AuthCodeStorageProtocol``. This design allows for flexible deployment configurations:
///
/// - **Production**: Redis-backed persistent storage
/// - **Development/Testing**: Fast in-memory storage
/// - **Custom**: User-provided storage implementation
///
/// ## Thread Safety
///
/// All operations are async and thread-safe through Swift's concurrency model. The struct conforms to `Sendable`,
/// making it safe to pass across concurrency boundaries.
///
/// ## Topics
///
/// ### Creating a Storage Instance
///
/// - ``init(use:)``
///
/// ### Session Management
///
/// - ``set(authSession:)``
/// - ``get(type:codeValue:remove:)``
/// - ``delete(type:codeValue:)``
/// - ``wipe(tenant:subject:)``
///
/// ### Login Session Management
///
/// - ``push(loginId:)``
/// - ``pull(loginUuid:)``
///
/// ### Monitoring
///
/// - ``count()``
/// - ``isHealthy()``
///
/// ## Example Usage
///
/// ```swift
/// // Initialize with Redis backend (production)
/// let storage = AuthCodeStorage(use: .redis(redisClient))
///
/// // Store an authorization session
/// try await storage.set(authSession: session)
///
/// // Retrieve and remove a session
/// if let session = await storage.get(
///     type: .code,
///     codeValue: "abc123",
///     remove: true
/// ) {
///     // Process the authorization code
/// }
///
/// // Check storage health
/// let healthy = await storage.isHealthy()
/// ```
///
/// ## See Also
///
/// - ``AuthCodeStorageProtocol``
/// - ``AuthSession``
/// - ``LoginSession``
struct AuthCodeStorage: AuthCodeStorageProtocol, Sendable {

    /// The underlying storage implementation that handles actual data persistence.
    private let implementation: AuthCodeStorageProtocol

    /// Creates a new authorization code storage with the specified backend implementation.
    ///
    /// - Parameter use: The storage backend to use. See ``AuthCodeStorageImplementations`` for available options.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Production: Redis storage
    /// let storage = AuthCodeStorage(use: .redis(client))
    ///
    /// // Development: In-memory storage
    /// let storage = AuthCodeStorage(use: .memory)
    ///
    /// // Custom: User-provided implementation
    /// let storage = AuthCodeStorage(use: .custom(implementation: myStorage))
    /// ```
    init(use: AuthCodeStorageImplementations) {
        switch use {
        case .redis(let client):
            implementation = RedisAuthCodeStorage(client)
        case .memory:
            implementation = MemoryAuthCodeStorage()
        case .custom(implementation: let customImplementation):
            implementation = customImplementation
        }
    }

    // MARK: - AuthCodeStorageProtocol

    /// Stores an authorization session in the backend.
    ///
    /// This method persists the authorization session and updates Prometheus metrics tracking
    /// the number of stored tokens. The metrics update happens asynchronously to avoid blocking
    /// the storage operation.
    ///
    /// - Parameter session: The authorization session to store.
    /// - Throws: An error if the storage operation fails (e.g., network error with Redis).
    ///
    /// ## Implementation Notes
    ///
    /// The method spawns a background thread to update metrics without blocking the main operation.
    /// This ensures fast response times for OAuth flows while maintaining observability.
    func set(authSession session: AuthSession) async throws {
        try await implementation.set(authSession: session)
        let thread = Thread { [self] in
            Log.debug("Counting keys in AuthStorage...")
            Task {
                let countKeysInStorage = await count()
                Log.debug("Found \(countKeysInStorage) keys in AuthStorage")
                Prometheus.main.tokensStored?.observe(countKeysInStorage)
            }
        }
        thread.main()
    }

    /// Retrieves an authorization session by its code type and value.
    ///
    /// - Parameters:
    ///   - codeType: The type of code to retrieve (e.g., `.code` for authorization codes, `.refresh` for refresh tokens).
    ///   - value: The unique code value to look up.
    ///   - remove: If `true`, removes the session from storage after retrieval. Defaults to `false`.
    ///
    /// - Returns: The stored authorization session, or `nil` if not found.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Retrieve and consume an authorization code (OAuth2 flow)
    /// if let session = await storage.get(
    ///     type: .code,
    ///     codeValue: authCode,
    ///     remove: true
    /// ) {
    ///     // Code is valid and has been removed (single-use)
    /// }
    /// ```
    func get(
        type codeType: AuthSession.CodeType,
        codeValue value: String,
        remove: Bool? = false
    ) async -> AuthSession? {
        Log.debug("Get AuthSession for type \(codeType.rawValue) with value \(value)")
        return await implementation.get(type: codeType, codeValue: value, remove: remove)
    }

    /// Stores a login session in the pending login registry.
    ///
    /// Login sessions track in-progress authentication attempts before authorization codes are issued.
    /// This allows the system to maintain state between the initial login request and the authorization callback.
    ///
    /// - Parameter session: The login session to store.
    /// - Throws: An error if the storage operation fails.
    func push(loginId session: LoginSession) async throws {
        Log.debug("Push AuthSession loginId: \(session.loginId.uuidString)")
        try await implementation.push(loginId: session)
    }

    /// Retrieves and removes a pending login session by its unique identifier.
    ///
    /// This operation is typically used to verify that a login callback corresponds to a valid
    /// in-progress authentication attempt. The session is removed atomically to prevent replay attacks.
    ///
    /// - Parameter uuid: The unique identifier of the login session.
    /// - Returns: `true` if the session was found and removed, `false` otherwise.
    func pull(loginUuid uuid: UUID) async -> Bool {
        Log.debug("Pull AuthSession loginUuid: \(uuid.uuidString)")
        return await implementation.pull(loginUuid: uuid)
    }

    /// Returns the total number of stored sessions across all types.
    ///
    /// This includes authorization codes, refresh tokens, and any other session types
    /// maintained by the storage backend. Useful for monitoring and metrics.
    ///
    /// - Returns: The count of stored sessions.
    func count() async -> Int {
        Log.debug("Count AuthSession")
        return await implementation.count()
    }

    /// Deletes a specific authorization session by its code type and value.
    ///
    /// This method is used to explicitly invalidate a code or token, such as when a user
    /// logs out or when a token is revoked.
    ///
    /// - Parameters:
    ///   - codeType: The type of code to delete.
    ///   - value: The unique code value to remove.
    /// - Throws: An error if the delete operation fails.
    func delete(type codeType: AuthSession.CodeType, codeValue value: String) async throws {
        Log.debug("Delete AuthSession for type \(codeType.rawValue) with value: \(value)")
        try await implementation.delete(type: codeType, codeValue: value)
    }

    /// Removes all sessions for a specific tenant and subject (user).
    ///
    /// This is typically used during logout operations to invalidate all active sessions
    /// for a user across the tenant, including authorization codes and refresh tokens.
    ///
    /// - Parameters:
    ///   - tenant: The tenant whose sessions should be wiped.
    ///   - subject: The subject (user identifier) whose sessions should be removed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Logout: wipe all sessions for user
    /// await storage.wipe(tenant: currentTenant, subject: userId)
    /// ```
    func wipe(tenant: Tenant, subject: String) async {
        Log.debug("Wipe AuthSession for tenant: \(tenant.name) with subject: \(subject)")
        await implementation.wipe(tenant: tenant, subject: subject)
    }

    /// Checks whether the storage backend is operational and able to serve requests.
    ///
    /// This health check is used by monitoring systems to verify the availability of
    /// the storage layer. For Redis backends, this typically involves a ping operation.
    ///
    /// - Returns: `true` if the storage is healthy, `false` otherwise.
    func isHealthy() async -> Bool {
        await implementation.isHealthy()
    }
}

/// A storage key for registering ``AuthCodeStorage`` in Vapor's application storage.
///
/// This key enables dependency injection of the authorization code storage throughout
/// the Vapor application via the storage container pattern.
///
/// ## See Also
///
/// - ``Application/authCodeStorage``
struct AuthCodeStorageKey: StorageKey {
    typealias Value = AuthCodeStorage
}

/// Vapor application extension providing access to authorization code storage.
extension Application {
    /// The authorization code storage instance for this application.
    ///
    /// This property provides centralized access to the configured storage backend
    /// throughout the Vapor application. It's typically set during application
    /// configuration based on environment settings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Configure in configure.swift
    /// if app.environment == .production {
    ///     app.authCodeStorage = AuthCodeStorage(use: .redis(redisClient))
    /// } else {
    ///     app.authCodeStorage = AuthCodeStorage(use: .memory)
    /// }
    ///
    /// // Access in route handlers
    /// func token(req: Request) async throws -> TokenResponse {
    ///     let storage = req.application.authCodeStorage
    ///     let session = await storage?.get(type: .code, codeValue: code)
    ///     // ...
    /// }
    /// ```
    var authCodeStorage: AuthCodeStorage? {
        get {
            storage[AuthCodeStorageKey.self]
        }
        set {
            storage[AuthCodeStorageKey.self] = newValue
        }
    }
}
