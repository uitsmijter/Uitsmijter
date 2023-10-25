import Foundation

/// Extend Set of Tenant
///
extension Set where Element == Tenant {

    /// Custom implementation of `Set:insert(Element:)` to add custom functionality
    ///
    /// Tenants can only added when the hosts are unique.
    ///
    /// - Important: It is forbidden to add a tenant with a host that is already used by another tenant.
    ///
    /// - Parameter newMember: Element of type Tenant
    /// - Returns: (inserted: Bool, memberAfterInsert: Tenant)
    ///
    @discardableResult mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {

        // check if tenant can be insert
        let alreadyKnownHosts = newMember.config.hosts.compactMap { host in
            Tenant.find(forHost: host)
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

        // add
        self = union([newMember])

        // ok
        return (true, newMember)
    }
}
