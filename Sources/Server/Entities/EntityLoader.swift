import Foundation
import Vapor

enum EntityLoaderError: Error {
    case canNotLoad(from: URL)
    case noLoaderRegistered
    case clientError
    case listTenants(reason: String?)
    case listClients(reason: String?)
}

/// A EntityLoader loads entities from different sources, like CRDs for example
protocol EntityLoaderProtocol {
    init(handler: EntityLoaderProtocolFunctions?) throws
    func start() throws
    func shutdown()
}

/// Definition of functions, that a EntityLoaderProtocol can call on `EntityLoader` to manipulate the entities.
protocol EntityLoaderProtocolFunctions {
    @discardableResult func addEntity(entity: Entity) -> Bool
    func removeEntity(entity: Entity)
}

/// Load entities from file (and EntityLoader's)
/// Provide static Sets of [`Tenant`] and [`Client`]
final class EntityLoader: EntityLoaderProtocolFunctions {

    /// Registered entity loaders
    var entityLoaders: [EntityLoaderProtocol] = []

    let storage: EntityStorage

    let tenantTemplateLoader = TenantTemplateLoader()

    /// Initialize and load all Entities from various places
    /// - Warning: Register an EntityLoader only once for an entire application!
    ///
    /// - Throws:
    @discardableResult init(storage useStorage: EntityStorage) throws {
        storage = useStorage

        // initial load all entity configurations from filesystem
        entityLoaders.append(try EntityFileLoader(handler: self))
        // load from crd if supported
        if Constants.RUNTIME.SUPPORT_KUBERNETES_CRD {
            entityLoaders.append(try EntityCRDLoader(handler: self))
        }

        try entityLoaders.forEach { loader in
            try loader.start()
        }
    }

    deinit {
        entityLoaders.forEach { loader in
            loader.shutdown()
        }
    }

    // MARK: - EntityLoaderProtocolFunctions

    /// Add a new `Entity` to the stack of globally known entities
    ///
    /// - Parameter entity: Implementation of an `Entity`
    @discardableResult
    func addEntity(entity: Entity) -> Bool {
        switch entity {
        case let tenant as Tenant:
            let (inserted, _) = storage.tenants.insert(tenant)
            Task {
                await tenantTemplateLoader.operate(operation: .create(tenant: tenant))
            }
            return inserted
        case let client as Client:
            storage.clients.append(client)
            return true
        default:
            Log.error("Can not add entity, because the type is unhandled.")
            return false
        }
    }

    func removeEntity(entity: Entity) {
        guard let reference = entity.ref else {
            Log.error("Try to remove an entity without reference is not possible.")
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
        case let client as Client:
            Log.info("Remove client \(client.name) with reference \(reference.description)")
            guard let index = storage.clients.firstIndex(where: { $0.ref == ref }) else {
                Log.error("Client \(client.name) with reference \(reference) not found for removal")
                return
            }
            storage.clients.remove(at: index)
        default:
            Log.error("Can not remove entity, because the type is unhandled.")
        }
    }
}
