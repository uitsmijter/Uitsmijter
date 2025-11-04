import Foundation

/// The type of requested response in an OAuth2 authorization request.
///
/// This enum defines the possible response types that a client can request
/// when initiating an OAuth2 authorization flow.
///
/// ## Topics
///
/// ### Response Types
/// - ``code``
enum ResponseType: String, Codable, Sendable {
    /// Authorization code response type.
    ///
    /// Indicates that the application expects to receive an authorization code
    /// if the authorization is successful. This is the standard flow for
    /// server-side applications.
    ///
    /// The authorization code can then be exchanged for an access token
    /// through the token endpoint.
    case code
}
