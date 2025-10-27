import Foundation
import Logger

// MARK: - Client Tenant Resolution

/// Tenant resolution methods for client specifications.
///
/// Provides methods to resolve the parent tenant for a client based on
/// the `tenantname` field in the client configuration.
///
/// ## Topics
///
/// ### Tenant Resolution
/// - ``tenant(in:)``
///
/// - SeeAlso: ``Tenant``
/// - SeeAlso: ``EntityStorage``
public extension ClientSpec {
    /// Resolves the tenant that owns this client.
    ///
    /// This method looks up the tenant by name from the client's `tenantname`
    /// configuration field.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let clientSpec: ClientSpec = ...
    /// if let tenant = clientSpec.tenant(in: app.entityStorage) {
    ///     print("Client belongs to tenant: \(tenant.name)")
    /// }
    /// ```
    ///
    /// - Parameter storage: The entity storage to search for the tenant
    /// - Returns: The tenant if found, or `nil` if no matching tenant exists
    ///
    /// - SeeAlso: ``ClientSpec/tenantname``
    /// - SeeAlso: ``Tenant/find(in:name:)``
    @MainActor func tenant(in storage: EntityStorage) -> Tenant? {
        Log.info("Try to find tenant with name: \(tenantname)")
        return Tenant.find(in: storage, name: tenantname)
    }
}
