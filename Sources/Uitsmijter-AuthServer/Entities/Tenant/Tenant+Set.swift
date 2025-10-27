import Foundation
import Logger

/// Extends Set operations for tenant collections with validation.
///
/// This extension adds custom insertion logic to enforce the constraint that
/// tenant hosts must be unique across all tenants. It prevents configuration
/// conflicts where multiple tenants try to serve the same host.
public extension Set where Element == Tenant {

    /// Insert a tenant into the set with host uniqueness validation.
    ///
    /// This method overrides the standard `Set.insert(_:)` to add validation
    /// that prevents tenants from being added if their configured hosts conflict
    /// with existing tenants.
    ///
    /// ## Host Uniqueness Constraint
    ///
    /// A tenant can only be added if none of its configured hosts conflict with
    /// hosts from existing tenants. The validation supports both exact matches
    /// and wildcard patterns.
    ///
    /// ## Conflict Detection
    ///
    /// Conflicts are detected using the same wildcard matching logic as tenant
    /// lookup. For example:
    /// - If tenant A has host `*.example.com`
    /// - And tenant B tries to add host `app.example.com`
    /// - The insertion fails because `app.example.com` matches the wildcard
    ///
    /// ## Example
    ///
    /// ```swift
    /// var tenants: Set<Tenant> = []
    ///
    /// // First tenant succeeds
    /// let tenant1 = Tenant(name: "acme", config: TenantSpec(hosts: ["acme.com"]))
    /// let result1 = tenants.insert(tenant1)
    /// // result1.inserted == true
    ///
    /// // Second tenant with conflicting host fails
    /// let tenant2 = Tenant(name: "other", config: TenantSpec(hosts: ["acme.com"]))
    /// let result2 = tenants.insert(tenant2)
    /// // result2.inserted == false (host conflict)
    /// ```
    ///
    /// ## Error Logging
    ///
    /// When insertion fails due to host conflicts, an error is logged with:
    /// - The name of the tenant that couldn't be added
    /// - The number of conflicting hosts
    /// - Details of which hosts are already taken
    ///
    /// - Parameter newMember: The tenant to insert
    /// - Returns: A tuple indicating whether the insertion succeeded and the tenant instance
    ///   - `inserted`: `true` if the tenant was added, `false` if rejected due to host conflicts
    ///   - `memberAfterInsert`: The tenant instance (either newly added or rejected)
    @MainActor
    @discardableResult mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {

        // Check if tenant can be inserted by validating host uniqueness
        let alreadyKnownHosts = newMember.config.hosts.compactMap { host in
            self.first { existingTenant in
                existingTenant.config.hosts.contains(where: { entry in
                    host == entry || host.matchesWildcard(regex: entry)
                })
            }
        }
        if alreadyKnownHosts.isEmpty == false {
            let isPluralism = alreadyKnownHosts.count == 1 ? "is" : "are"
            Log.error(.init(
                stringLiteral: """
                                   Tenant \(newMember.name) can't be added, because there \(isPluralism)
                                    \(alreadyKnownHosts.count) host that \(isPluralism) already taken.
                                   """.replacingOccurrences(of: "\n", with: "")
            )
            )
            return (false, newMember)
        }

        // Add the tenant using set union to maintain immutability
        self = union([newMember])

        // Return success
        return (true, newMember)
    }
}
