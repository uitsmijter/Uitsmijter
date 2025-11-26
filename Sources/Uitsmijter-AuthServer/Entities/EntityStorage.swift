import Foundation
import Logger

/// Central storage for all loaded entities in the Uitsmijter system.
///
/// `EntityStorage` is the single source of truth for tenants and clients loaded from
/// YAML files or Kubernetes Custom Resource Definitions (CRDs). It maintains collections
/// of these entities and provides change tracking, logging, and metrics integration.
///
/// ## Thread Safety
///
/// This class is marked with `@MainActor` to ensure all entity access happens on the
/// main actor, providing thread-safe access to the entity collections. All entity
/// manipulation must happen from the main actor context.
///
/// ## Change Tracking
///
/// The storage uses property observers (`willSet` and `didSet`) to:
/// - Log when entities are added or removed
/// - Update Prometheus metrics counters
/// - Trigger test hooks in debug builds
///
/// ## Test Isolation
///
/// Each Vapor `Application` instance gets its own `EntityStorage` via the
/// `Application.entityStorage` extension. This ensures test isolation when
/// tests run in parallel, as each test creates its own `Application` instance.
///
/// ## Usage Example
///
/// ```swift
/// // Access via Application
/// let storage = app.entityStorage
///
/// // Add a tenant
/// storage.tenants.insert(tenant)
///
/// // Add a client
/// storage.clients.append(client)
///
/// // Query entities
/// let tenant = Tenant.find(byName: "acme", in: storage)
/// let client = UitsmijterClient.find(byIdent: "web-app", in: storage)
/// ```
///
/// ## Debug Hooks
///
/// In debug builds, you can attach a hook to observe entity changes:
///
/// ```swift
/// #if DEBUG
/// storage.hook = { type, entity in
///     print("Entity changed: \(type), \(entity?.name ?? "nil")")
/// }
/// #endif
/// ```
///
/// - SeeAlso: ``Entity``, ``Tenant``, ``UitsmijterClient``
@MainActor
final class EntityStorage {

    #if DEBUG
    /// Hook for observing entity changes in tests.
    ///
    /// This hook is called whenever an entity is added or removed from storage.
    /// It's only available in debug builds to support testing.
    ///
    /// - Parameters:
    ///   - ManagedEntityType: The type of entity that changed
    ///   - Entity?: The entity that was added, or `nil` if removed
    var hook: (@Sendable (ManagedEntityType, Entity?) -> Void)?
    #endif

    /// Dictionary tracking denied login attempts per client.
    ///
    /// Key is the client name, value is the count of denied login attempts.
    /// This is reset when clients are reloaded or manually cleared.
    var deniedLoginAttempts: [String: Int] = [:]

    /// Increment denied login attempts for a client.
    ///
    /// - Parameter clientName: The name of the client that had a failed login
    func incrementDeniedAttempts(for clientName: String) {
        deniedLoginAttempts[clientName, default: 0] += 1
        Log.debug("Denied login attempt for client: \(clientName), total: \(deniedLoginAttempts[clientName] ?? 0)")
    }

    /// Get denied login attempts for a client.
    ///
    /// - Parameter clientName: The name of the client
    /// - Returns: The number of denied login attempts, or 0 if none
    func getDeniedAttempts(for clientName: String) -> Int {
        return deniedLoginAttempts[clientName] ?? 0
    }

    /// Initialize a new entity storage instance.
    ///
    /// In production, there's typically one storage instance per application.
    /// In tests, each test gets its own instance for isolation.
    init() {
        #if DEBUG
        self.hook = nil
        #endif
    }

    /// The collection of all loaded tenant entities.
    ///
    /// Tenants represent organizations or domains that can contain multiple clients.
    /// The set is automatically managed by entity loaders, which add, update, or
    /// remove tenants as their source files change.
    ///
    /// ## Change Notifications
    ///
    /// When tenants are added or removed:
    /// - Log messages are emitted with tenant details
    /// - Prometheus metrics are updated
    /// - Debug hooks are called (in debug builds)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Add a tenant
    /// storage.tenants.insert(newTenant)
    ///
    /// // Remove a tenant
    /// storage.tenants.remove(oldTenant)
    ///
    /// // Query tenants
    /// let allTenants = storage.tenants
    /// ```
    ///
    /// - SeeAlso: ``Tenant``
    var tenants: Set<Tenant> = [] {
        willSet {
            // Added Tenants
            if newValue.count > tenants.count {
                let newTenants = newValue.symmetricDifference(tenants)
                guard let newTenant = newTenants.first else {
                    Log.error("Invalid tenant provided for insertion")
                    return
                }
                Log.info(
                    "Add new tenant '\(newTenant.name)' with \(newTenant.config.hosts.count) hosts"
                )
            }
            // Removed Tenants
            else if newValue.count < tenants.count {
                let removedTenants = newValue.symmetricDifference(tenants)
                removedTenants.forEach { tenant in
                    Log.info("Remove tenant '\(tenant.name)'")
                }
                return
            }

        }
        didSet {
            Prometheus.main.countTenants?.set(tenants.count)
            let newTenants = tenants.symmetricDifference(oldValue)
            guard let newTenant = newTenants.first else {
                return
            }
            #if DEBUG
            hook?(.tenant, newTenant)
            #endif
        }
    }
    /// The collection of all loaded client entities.
    ///
    /// Clients represent OAuth2 applications that belong to a tenant. Each client
    /// has configuration for OAuth2 flows, redirect URIs, and authentication settings.
    /// The array is automatically managed by entity loaders.
    ///
    /// ## Change Notifications
    ///
    /// When clients are added or removed:
    /// - Log messages are emitted with client and tenant details
    /// - Prometheus metrics are updated
    /// - Debug hooks are called (in debug builds)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Add a client
    /// storage.clients.append(newClient)
    ///
    /// // Remove a client
    /// storage.clients.removeAll { $0.config.ident == "old-client" }
    ///
    /// // Query clients
    /// let allClients = storage.clients
    /// ```
    ///
    /// - Note: Unlike tenants which use a `Set`, clients use an `Array` to maintain
    ///   insertion order. This is a legacy design that may be refactored in the future.
    ///
    /// - SeeAlso: ``UitsmijterClient``
    var clients: [UitsmijterClient] = [] {
        willSet {
            // Added Clients
            if newValue.count > clients.count {
                if let newClient = newValue.last {
                    let msg = "Add new client '\(newClient.name)' [\(newClient.config.ident)] "
                        + "for tenant '\(newClient.config.tenantname)'"
                    Log.info(msg)
                }
                return
            }
            // Removed Clients
            else if newValue.count < clients.count {
                newValue.difference(from: clients).removals.forEach { removal in
                    switch removal {
                    case .remove(_, let removedClient, _):
                        let msg = """
                                  Remove client '\(removedClient.name)' [\(removedClient.config.ident)]
                                   from tenant '\(removedClient.config.tenantname)'
                                  """.replacingOccurrences(of: "\n", with: "")
                        Log.info(msg)
                    default:
                        return
                    }
                }
                return
            }

            // Ignore the changed operations that atomic write produces.
            // we will get rid of it, when static clients is not accessible in future development
            Log.debug("Reset global clients")
        }
        didSet {
            Prometheus.main.countClients?.set(clients.count)
            #if DEBUG
            if let newClient = clients.last {
                hook?(.client, newClient)
            } else {
                hook?(.client, nil)
            }
            #endif
        }
    }
}
