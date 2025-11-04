import Foundation

/// Hashable conformance for Client
///
/// Clients are hashed based on their name to enable efficient storage
/// and lookup in sets and dictionaries.
extension Client: Hashable {

    /// Compare two clients for equality.
    ///
    /// Clients are considered equal if they have the same name,
    /// as name is the primary identifier.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side client
    ///   - rhs: The right-hand side client
    /// - Returns: `true` if both clients have the same name
    static func == (lhs: Client, rhs: Client) -> Bool {
        lhs.name == rhs.name
    }

    /// Hash the client using its name.
    ///
    /// Two clients with the same name will hash to the same value,
    /// making name the primary identifier for equality and hashing.
    ///
    /// - Parameter hasher: The hasher to combine values into
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
