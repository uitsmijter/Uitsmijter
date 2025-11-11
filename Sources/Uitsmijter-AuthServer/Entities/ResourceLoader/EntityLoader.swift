import Foundation
import Logger

// MARK: - Entity Loader

/// Orchestrates loading of tenant and client entities from multiple sources.
///
/// This class serves as the main entry point for entity loading in the application.
/// It coordinates multiple entity loaders (file-based, Kubernetes CRDs, etc.) and
/// provides a unified interface for managing entities in the global storage.
///
/// The entity loader:
/// - Loads entities from the filesystem (YAML files)
/// - Optionally loads from Kubernetes CRDs (when enabled)
/// - Manages tenant-specific S3 templates via ``TenantTemplateLoader``
/// - Automatically starts monitoring for changes
///
/// ## Topics
///
/// ### Initialization
/// - ``init(storage:)``
///
/// ### Entity Management
/// - ``addEntity(entity:)``
/// - ``removeEntity(entity:)``
///
/// - Important: Only one EntityLoader should be created per application instance.
/// - SeeAlso: ``EntityLoaderProtocol``, ``EntityStorage``
@MainActor
public final class EntityLoader: EntityLoaderProtocolFunctions {

    /// All registered entity loader implementations.
    ///
    /// This array contains loaders for different sources (files, Kubernetes CRDs).
    /// Loaders are automatically started during initialization and shut down on deinit.
    ///
    /// - Note: This property is MainActor-isolated, ensuring thread-safe access
    ///   to the loader registry.
    var entityLoaders: [EntityLoaderProtocol] = []

    /// The storage where loaded entities are kept.
    let storage: EntityStorage

    /// Manages loading and cleanup of tenant-specific S3 templates.
    let tenantTemplateLoader = TenantTemplateLoader()

    /// Initializes the entity loader and starts loading from all configured sources.
    ///
    /// This initializer:
    /// 1. Registers file-based entity loading (always enabled)
    /// 2. Registers Kubernetes CRD loading (if ``RuntimeConfiguration/SUPPORT_KUBERNETES_CRD`` is true)
    /// 3. Starts all registered loaders to begin monitoring for changes
    ///
    /// - Parameter storage: The entity storage to populate with loaded entities
    /// - Throws: ``EntityLoaderError`` if any loader fails to initialize or start
    /// - Warning: Only create one EntityLoader instance per application!
    /// - SeeAlso: ``RuntimeConfiguration/SUPPORT_KUBERNETES_CRD``
@discardableResult init(storage useStorage: EntityStorage) throws {
        storage = useStorage

        // initial load all entity configurations from filesystem
        entityLoaders.append(try EntityFileLoader(handler: self))
        // load from crd if supported
        if RuntimeConfiguration.SUPPORT_KUBERNETES_CRD {
            entityLoaders.append(try EntityCRDLoader(handler: self))
        }

        try entityLoaders.forEach { loader in
            try loader.start()
        }
    }

    deinit {
        // Note: We cannot call shutdown() from deinit because deinit is nonisolated
        // and entityLoaders is MainActor-isolated. The loaders will be cleaned up
        // when the EntityLoader instance is deallocated.
        // If explicit cleanup is needed, call shutdown() manually before deallocation.
    }

    /// Manually shuts down all registered entity loaders.
    ///
    /// Call this method explicitly if you need to ensure all loaders are properly
    /// shut down before the EntityLoader is deallocated.
    ///
    /// - Note: This method is MainActor-isolated to safely access the loaders.
    public func shutdown() {
        entityLoaders.forEach { loader in
            loader.shutdown()
        }
    }

    // MARK: - EntityLoaderProtocolFunctions

    /// Adds a new entity to the global entity storage.
    ///
    /// This method handles adding both tenant and client entities:
    /// - **Tenants**: Added to storage and trigger S3 template loading if configured
    /// - **Clients**: Added to storage directly
    ///
    /// - Parameter entity: The entity to add (``Tenant`` or ``UitsmijterClient``)
    /// - Returns: `true` if the entity was added successfully, `false` if the type is unsupported
    /// - SeeAlso: ``removeEntity(entity:)``
    @discardableResult
    func addEntity(entity: Entity) -> Bool {
        switch entity {
        case let tenant as Tenant:
            let (inserted, _) = storage.tenants.insert(tenant)
            Task {
                await tenantTemplateLoader.operate(operation: .create(tenant: tenant))
            }
            return inserted
        case let client as UitsmijterClient:
            storage.clients.append(client)
            return true
        default:
            Log.error("Cannot add entity: unhandled entity type")
            return false
        }
    }

    /// Removes an entity from the global entity storage.
    ///
    /// This method handles removing both tenant and client entities. For tenants,
    /// it also triggers cleanup of associated S3 templates.
    ///
    /// The method matches entities by their reference, supporting both file-based
    /// and Kubernetes CRD references. For Kubernetes entities, the revision is
    /// ignored during matching to ensure proper removal.
    ///
    /// - Parameter entity: The entity to remove (``Tenant`` or ``UitsmijterClient``)
    /// - Note: Entities without a reference cannot be removed and will log an error
    /// - SeeAlso: ``addEntity(entity:)``
    func removeEntity(entity: Entity) {
        guard let reference = entity.ref else {
            Log.error("Cannot remove entity without reference")
            return
        }

        var ref = reference
        if case let .kubernetes(uuid, _) = ref {
            ref = .kubernetes(uuid)
        }

        switch entity {
        case let tenant as Tenant:
            Log.info("Remove tenant \(tenant.name) with reference \(reference.description)")
            Task {
                await tenantTemplateLoader.operate(operation: .remove(tenant: tenant))
            }

            guard let index = storage.tenants.firstIndex(where: { $0.ref == ref }) else {
                Log.error("Tenant \(tenant.name) with reference \(reference) not found for removal")
                return
            }
            storage.tenants.remove(at: index)
        case let client as UitsmijterClient:
            Log.info("Remove client \(client.name) with reference \(reference.description)")
            guard let index = storage.clients.firstIndex(where: { $0.ref == ref }) else {
                Log.error("Client \(client.name) with reference \(reference) not found for removal")
                return
            }
            storage.clients.remove(at: index)
        default:
            Log.error("Cannot remove entity: unhandled entity type")
        }
    }
}
