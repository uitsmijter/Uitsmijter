import Vapor

/// A storage key for registering ``AuthEventActor`` in Vapor's application storage.
///
/// This key enables dependency injection of the auth event actor throughout
/// the Vapor application via the storage container pattern.
///
/// ## See Also
///
/// - ``Application/authEventActor``
struct AuthEventActorKey: StorageKey {
    typealias Value = AuthEventActor
}

/// Vapor application extension providing access to the authentication event actor.
extension Application {
    /// The authentication event actor instance for this application.
    ///
    /// This property provides centralized access to the auth event actor that handles
    /// all authentication events (login success/failure, logout) by combining Prometheus
    /// metrics recording and entity status updates.
    ///
    /// The actor is initialized during application configuration with references to
    /// `entityStorage` and `entityLoader`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Configure in configure.swift
    /// app.authEventActor = AuthEventActor(
    ///     entityStorage: app.entityStorage,
    ///     entityLoader: app.entityLoader
    /// )
    ///
    /// // Access in route handlers
    /// func login(req: Request) async throws -> Response {
    ///     // ... authenticate user ...
    ///     await req.application.authEventActor.recordLoginSuccess(
    ///         tenant: tenant.name,
    ///         client: clientInfo.client,
    ///         mode: clientInfo.mode.rawValue,
    ///         host: req.forwardInfo?.location.host ?? "unknown"
    ///     )
    ///     // ...
    /// }
    /// ```
    ///
    /// - Note: The actor must be initialized after both `entityStorage` and `entityLoader`
    ///   are configured, as it depends on both.
    /// - SeeAlso: ``AuthEventActor``, GitHub Issue #78
    @MainActor var authEventActor: AuthEventActor {
        get {
            // Get existing instance or create new one
            if let existing = storage[AuthEventActorKey.self] {
                return existing
            }
            // Create new instance with current entityStorage and entityLoader
            let new = AuthEventActor(
                entityStorage: entityStorage,
                entityLoader: entityLoader
            )
            storage[AuthEventActorKey.self] = new
            return new
        }
        set {
            storage[AuthEventActorKey.self] = newValue
        }
    }
}
