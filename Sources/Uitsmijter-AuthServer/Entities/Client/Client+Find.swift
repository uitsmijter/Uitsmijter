import Foundation

// MARK: - Entity Protocol Conformance

/// Extends `Client` to conform to EntityFindResourceReferenceProtocol
extension Client: EntityFindResourceReferenceProtocol {}

// MARK: - Client Lookup Methods

/// Client lookup and search methods.
///
/// Provides various methods to find clients in entity storage by different criteria
/// such as UUID, name, or entity reference.
///
/// ## Topics
///
/// ### Lookup Methods
/// - ``find(in:clientId:)``
/// - ``find(in:name:tenant:)``
/// - ``find(in:ref:)``
///
/// - SeeAlso: ``EntityStorage``
/// - SeeAlso: ``Tenant``
extension Client {

    /// Finds a client by its UUID identifier.
    ///
    /// This is the primary lookup method used when a `client_id` is provided
    /// in OAuth requests or token endpoints.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let client = Client.find(
    ///     in: app.entityStorage,
    ///     clientId: "550e8400-e29b-41d4-a716-446655440000"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - storage: The entity storage to search
    ///   - id: The client's UUID string (case-insensitive)
    /// - Returns: The matching client, or `nil` if not found
    ///
    /// - SeeAlso: ``ClientSpec/ident``
    @MainActor static func find(in storage: EntityStorage, clientId id: String) -> Client? {
        storage.clients.first { firstClient in
            firstClient.config.ident.uuidString.lowercased() == id.lowercased()
        }
    }

    /// Finds a client by name within a specific tenant.
    ///
    /// This method searches for a client with the given name that belongs to
    /// the specified tenant. Useful when multiple tenants may have clients
    /// with the same name.
    ///
    /// - Parameters:
    ///   - storage: The entity storage to search
    ///   - name: The client's name
    ///   - tenant: The tenant that owns the client
    /// - Returns: The matching client, or `nil` if not found
    ///
    /// - SeeAlso: ``Client/name``
    /// - SeeAlso: ``ClientSpec/tenant(in:)``
    @MainActor static func find(in storage: EntityStorage, name: String, tenant: Tenant) -> Client? {
        storage.clients.first { fistClient in
            fistClient.name == name && fistClient.config.tenant(in: storage)?.name == tenant.name
        }
    }

    /// Finds a client by its entity resource reference.
    ///
    /// This method is used internally by the entity system to resolve client
    /// references from YAML files or Kubernetes CRDs.
    ///
    /// - Parameters:
    ///   - storage: The entity storage to search
    ///   - ref: The entity resource reference
    /// - Returns: The matching client as an `Entity`, or `nil` if not found
    ///
    /// - SeeAlso: ``EntityResourceReference``
    /// - SeeAlso: ``EntityFindResourceReferenceProtocol``
    @MainActor static func find(in storage: EntityStorage, ref: EntityResourceReference) -> Entity? {
        storage.clients.first { firstClient in
            firstClient.ref == ref
        }
    }
}
