import Foundation

/// Base protocol that all client implementations must conform to.
///
/// Defines the minimum contract for OAuth2 client entities.
protocol ClientProtocol {
    /// The display name of this client.
    ///
    /// Used for identification and logging purposes.
    var name: String { get }

    /// The configuration specification for this client.
    ///
    /// Contains OAuth2 settings, redirect URIs, and security constraints.
    var config: ClientSpec { get }
}
