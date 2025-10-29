import Foundation

/// Extend Tenant to conform to Hashable for use in collections.
///
/// Tenants are identified by their unique name, which is used for
/// equality comparison and hashing.
extension Tenant: Hashable {
    /// Compare two tenants for equality.
    ///
    /// Tenants are considered equal if they have the same name.
    /// This allows storing tenants in a `Set` with automatic deduplication.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side tenant
    ///   - rhs: The right-hand side tenant
    /// - Returns: `true` if both tenants have the same name
    static func == (lhs: Tenant, rhs: Tenant) -> Bool {
        lhs.name == rhs.name
    }

    /// Generate a hash value for this tenant.
    ///
    /// The hash is based solely on the tenant name, matching the
    /// equality implementation.
    ///
    /// - Parameter hasher: The hasher to use for combining values
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// Extend TenantSpec to conform to Equatable and Hashable.
///
/// Tenant specifications are identified by their hosts configuration,
/// which must be unique across all tenants.
extension TenantSpec: Equatable, Hashable {
    /// Compare two tenant specifications for equality.
    ///
    /// Specifications are considered equal if they have the same hosts.
    /// This enforces the constraint that host lists must be unique.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side specification
    ///   - rhs: The right-hand side specification
    /// - Returns: `true` if both specifications have the same hosts
    static func == (lhs: TenantSpec, rhs: TenantSpec) -> Bool {
        lhs.hosts == rhs.hosts
    }

    /// Generate a hash value for this tenant specification.
    ///
    /// The hash is based solely on the hosts list, matching the
    /// equality implementation.
    ///
    /// - Parameter hasher: The hasher to use for combining values
    func hash(into hasher: inout Hasher) {
        hasher.combine(hosts)
    }
}
