import Foundation

/// Extends `Tenant` to return one found by criteria
///
extension Tenant: EntityFindResourceReferenceProtocol {

    /// Find a tenant by a host
    ///
    /// - Parameter host: String of the host that is served for the tenant
    /// - Returns: Optional Tenant is found.
    ///
    static func find(forHost host: String) -> Tenant? {
        EntityStorage.shared.tenants.first { firstTenant in
            firstTenant.config.hosts.contains(host)
        }
    }

    /// Find a tenant by name
    ///
    /// - Parameter tenantName: Registered name of teh tenant
    /// - Returns: Optional Tenant is found.
    ///
    static func find(name tenantName: String) -> Tenant? {
        EntityStorage.shared.tenants.first { firstTenant in
            firstTenant.name == tenantName
        }
    }

    /// Find a tenant by its reference
    ///
    /// - Parameter ref: EntityResourceReference to the tenants resource
    /// - Returns: Optional Tenants is found.
    ///
    static func find(ref: EntityResourceReference) -> Entity? {
        EntityStorage.shared.tenants.first { firstTenant in
            firstTenant.ref == ref
        }
    }
}
