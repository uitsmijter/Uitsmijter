import Foundation

/// Hashable conformance for Client
///
/// Clients are hashed based on their name to enable efficient storage
/// and lookup in sets and dictionaries.
extension Client: Hashable {
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
