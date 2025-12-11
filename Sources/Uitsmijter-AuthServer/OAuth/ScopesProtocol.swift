import Foundation

/// A protocol defining a type that contains OAuth2 scopes.
///
/// Types conforming to this protocol provide scope information that
/// defines the permissions being requested in an OAuth2 authorization flow.
///
/// Scopes are space-delimited strings that represent the level of access
/// the client is requesting.
///
/// ## Example
///
/// ```swift
/// struct MyRequest: ScopesProtocol {
///     let scope: String? = "read write profile"
/// }
/// ```
protocol ScopesProtocol {
    /// Optional requested scopes to get permissions for.
    ///
    /// A space-delimited list of scope values indicating the access
    /// requested by the application. For example: `"read write profile"`.
    ///
    /// If `nil`, the authorization server will use default scopes or
    /// prompt the user to select scopes.
    var scope: String? { get }
}
 
