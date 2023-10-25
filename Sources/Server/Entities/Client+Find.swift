import Foundation

/// Extends `Client` to return one found by criteria
extension Client: EntityFindResourceReferenceProtocol {

    /// Find a client by its ident
    ///
    /// - Parameter id: UUID sting of the clients ident
    /// - Returns: Optional Client is found.
    ///
    static func find(id: String) -> Client? {
        EntityStorage.shared.clients.first { firstClient in
            firstClient.config.ident.uuidString.lowercased() == id.lowercased()
        }
    }

    /// Find a client by its name
    ///
    /// - Parameters:
    ///    - name: Name of the clients
    ///    - tenant: The tenant for the searched client
    /// - Returns: Optional Client is found.
    ///
    static func find(name: String, tenant: Tenant) -> Client? {
        EntityStorage.shared.clients.first { fistClient in
            fistClient.name == name && fistClient.config.tenant?.name == tenant.name
        }
    }

    /// Find a client by its reference
    ///
    /// - Parameter ref: EntityResourceReference to the clients resource
    /// - Returns: Optional Client is found.
    ///
    static func find(ref: EntityResourceReference) -> Entity? {
        EntityStorage.shared.clients.first { firstClient in
            firstClient.ref == ref
        }
    }
}
