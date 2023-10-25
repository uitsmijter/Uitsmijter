import Foundation
import Vapor

final class EntityStorage {

    /// Application wide main storage
    static var shared: EntityStorage = EntityStorage()

    private init() {

    }

    #if DEBUG
    // hooks are only available in tests
    var hook: ((ManagedEntityType, Entity?) -> Void)?
    #endif

    var tenants: Set<Tenant> = [] {
        willSet {
            // Added Tenants
            if newValue.count > tenants.count {
                let newTenants = newValue.symmetricDifference(tenants)
                guard let newTenant = newTenants.first else {
                    Log.error("New tenant to insert invalid.")
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
            metricsCountTenants?.set(tenants.count)
            let newTenants = tenants.symmetricDifference(oldValue)
            guard let newTenant = newTenants.first else {
                return
            }
            #if DEBUG
            hook?(.tenant, newTenant)
            #endif
        }
    }
    var clients: [Client] = [] {
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
                        Log.info(.init(stringLiteral: msg))
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
            metricsCountClients?.set(clients.count)
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

struct EntityStorageKey: StorageKey {
    typealias Value = EntityStorage
}

extension Application {
    var entityStorage: EntityStorage? {
        get {
            storage[EntityStorageKey.self]
        }
        set {
            storage[EntityStorageKey.self] = newValue
        }
    }
}
