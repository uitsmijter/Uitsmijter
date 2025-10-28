import Foundation

/// Extends Tenant to conform to EntityFindResourceReferenceProtocol.
///
/// This enables tenants to be found by their resource reference, which is
/// used by the entity loading system for hot-reloading when source files change.
extension Tenant: EntityFindResourceReferenceProtocol {}

/// Tenant lookup and query methods.
///
/// This extension provides various methods for finding tenants in storage
/// based on different criteria: host matching, name, or resource reference.
extension Tenant {

    /// Find a tenant by matching a host against configured hosts.
    ///
    /// This method searches for a tenant whose configured hosts match the
    /// provided host string. Both exact matches and wildcard patterns are
    /// supported.
    ///
    /// ## Wildcard Matching
    ///
    /// The host matching supports wildcard patterns:
    /// - `*.example.com` matches `app.example.com`, `api.example.com`, etc.
    /// - `example.com` matches only exactly `example.com`
    ///
    /// ## Usage in Request Routing
    ///
    /// This method is primarily used during request handling to determine
    /// which tenant should process a request based on the `Host` or
    /// `X-Forwarded-Host` header.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Tenant configured with hosts: ["example.com", "*.example.com"]
    /// let tenant = Tenant.find(in: storage, forHost: "app.example.com")
    /// // Returns the tenant because "app.example.com" matches "*.example.com"
    ///
    /// let tenant2 = Tenant.find(in: storage, forHost: "other.com")
    /// // Returns nil because "other.com" doesn't match any hosts
    /// ```
    ///
    /// - Parameters:
    ///   - storage: The entity storage to search
    ///   - host: The host string to match against tenant configurations
    /// - Returns: The matching tenant, or `nil` if no match is found
    @MainActor static func find(in storage: EntityStorage, forHost host: String) -> Tenant? {
        storage.tenants.first { firstTenant in
            firstTenant.config.hosts.contains(where: {entry in
                host == entry || host.matchesWildcard(regex: entry)
            })
        }
    }

    /// Find a tenant by its unique name.
    ///
    /// This method performs a simple name lookup to find a specific tenant.
    /// Tenant names must be unique across the system.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let tenant = Tenant.find(in: storage, name: "acme-corp")
    /// if let tenant = tenant {
    ///     print("Found tenant: \(tenant.name)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - storage: The entity storage to search
    ///   - tenantName: The name of the tenant to find
    /// - Returns: The tenant with the specified name, or `nil` if not found
    @MainActor static func find(in storage: EntityStorage, name tenantName: String) -> Tenant? {
        storage.tenants.first { firstTenant in
            firstTenant.name == tenantName
        }
    }

    /// Find a tenant by its resource reference.
    ///
    /// This method is used by the entity loading system to find existing
    /// tenants when their source files or Kubernetes resources change,
    /// enabling hot-reload functionality.
    ///
    /// ## Hot-Reload Flow
    ///
    /// 1. File monitor detects a change to a tenant YAML file
    /// 2. EntityLoader finds the existing tenant by reference
    /// 3. EntityLoader updates the tenant with new configuration
    /// 4. EntityStorage reflects the updated tenant
    ///
    /// ## Example
    ///
    /// ```swift
    /// let ref = EntityResourceReference.file(URL(fileURLWithPath: "/path/to/tenant.yaml"))
    /// if let tenant = Tenant.find(in: storage, ref: ref) {
    ///     print("Found tenant from file: \(tenant.name)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - storage: The entity storage to search
    ///   - ref: The resource reference to search for
    /// - Returns: The tenant with the specified reference, or `nil` if not found
    @MainActor static func find(in storage: EntityStorage, ref: EntityResourceReference) -> Entity? {
        storage.tenants.first { firstTenant in
            firstTenant.ref == ref
        }
    }
}
