import Foundation

/// Protocol for types that have a client ID.
///
/// Used for parameter objects that need to carry a client identifier,
/// particularly in OAuth2 request handling.
protocol ClientIdProtocol {
    /// The OAuth2 client identifier.
    ///
    /// This is the public identifier used in OAuth2 flows (e.g., authorization requests).
    var client_id: String { get }
}

/// A concrete implementation of a client ID parameter for OAuth2 requests.
///
/// Used for decoding client ID from request parameters.
struct ClientIdParameter: ClientIdProtocol, Decodable {
    /// The OAuth2 client identifier extracted from the request.
    var client_id: String
}
