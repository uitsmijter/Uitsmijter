import Foundation
import Vapor

/// All AuthRequests have to implement this protocol
/// to implement shared functions that's needed to handle teh requests
protocol AuthRequestProtocol: Codable, ClientIdProtocol, RedirectUriProtocol, ScopesProtocol {

    /// Every request wants to be a specific response type.
    ///
    /// - SeeAlso: ResponseType
    var response_type: ResponseType { get }

    /// The application must have a known public identifier provided in the `client_id` property.
    /// The application must be known by authorization server.
    var client_id: String { get }

    /// Optional secret for this client
    var client_secret: String? { get }

    /// The `redirect_uri` must match one of the URLs the application registers when creating and the
    /// authorization server will reject the request if it does not match.
    var redirect_uri: URL { get }

    /// The request may have one or more scope values indicating additional access requested by the application.
    /// The authorization server will need to display the requested scopes to the user.
    var scope: String? { get }

    /// The state parameter is used by the application to store request-specific data and/or prevent CSRF
    /// attacks. The authorization server must return the unmodified state value back to the application.
    var state: String { get }
}

/// Shared functions for all AuthRequest implementations
extension AuthRequestProtocol {

    var redirectPath: String {
        get {
            redirect_uri.path
        }
    }
}

/// An `AuthRequest` is one of a `AuthRequestProtocol` implementation and can be made by a client for
/// a `response_type`.
/// The request uses this struct to define the request
///
/// - Parameters:
///     - response_type: The type of requested response
///     - client_id: The client who request the authorization response
///     - redirect_uri: Where the response should delegate to
///     - scope: Optional requested scopes to get permissions for
///     - state: A string send by the client that will be unchanged sends back in the respond
///
/// - SeeAlso:
///     - AuthRequestPKCE: for a PKCE version of a authorization request
///
/// ~~~
/// let authRequest = AuthRequest(
///     response_type: .code
///     client_id: "BCB2E4D2-4DCD-4D14-877B-397FB8490411"
///     redirect_uri: "https://mysite.example.com",
///     scope: "read write",
///     state: "aiZeij6t"
/// )
/// ~~~
struct AuthRequest: AuthRequestProtocol {
    /// The type of requested response, eg. `code`
    var response_type: ResponseType

    /// The client who request the authorization response
    var client_id: String

    /// Optional secret for this client
    var client_secret: String?

    /// Where the response should delegate to
    var redirect_uri: URL

    /// Optional requested scopes to get permissions for
    var scope: String?

    /// A string send by the client that will be unchanged sends back in the respond
    var state: String
}

/// An `AuthRequestPKCE` is one of a `AuthRequestProtocol` implementation and can be made by a client for
/// a `response_type`. It is used fora authentication code grant request with PKCE (Proof Key for Code Exchange).
/// The request uses this struct to define the request
///
/// - Parameters:
///     - response_type: The type of requested response, eg. `code`
///     - client_id: The client who request the authorization response
///     - redirect_uri: Where the response should delegate to
///     - scope: Optional requested scopes to get permissions for
///     - state: A string send by the client that will be unchanged sends back in the respond
///     - code_challenge: A random, high entropy string between 43 and 128 characters that is set by the client
///     - code_challenge_method: describes the encoding of the `code_challenge` string
///
/// - SeeAlso:
///     - AuthRequest: for a plain version of a authorization request
///
/// ~~~
/// let authRequest = AuthRequestPKCE(
///     response_type: .code
///     client_id: "BCB2E4D2-4DCD-4D14-877B-397FB8490411"
///     redirect_uri: "https://mysite.example.com",
///     scope: "read write",
///     state: "aiZeij6t".
///     code_challenge: "E9Melhoa20wvFrEMTJguCHaoeK1t8URWbuGjSstw-CM",
///     code_challenge_method: .sha265
/// )
/// ~~~
struct AuthRequestPKCE: AuthRequestProtocol {
    /// The type of requested response, eg. `code`
    var response_type: ResponseType

    /// The client who request the authorization response
    var client_id: String

    /// Optional secret for this client
    var client_secret: String?

    /// Where the response should delegate to
    var redirect_uri: URL

    /// Optional requested scopes to get permissions for
    var scope: String?

    /// A string send by the client that will be unchanged sends back in the respond
    var state: String

    /// When the user initiates an authentication flow, the client should compute a `code_verifier`. This
    /// must be a random, high entropy string between 43 and 128 characters.
    /// Next up, the client computes a `code_challenge` starting from the `code_verifier`.
    ///
    ///     Pseudocode:
    ///     code_challenge = base64urlEncode(SHA256(ASCII(code_verifier)))
    ///
    let code_challenge: String

    /// The `code_challenge_method` describes the encoding of the `code_challenge` string and can be for
    /// example one of:
    /// - .plain
    /// - .sha256
    ///
    let code_challenge_method: CodeChallengeMethod

}

/// Wrapper around the `AuthRequestProtocol` implementations.
///
/// - Returns:
///     - AuthRequest | AuthRequestPKCE
enum AuthRequests {
    case insecure(AuthRequest)
    case pkce(AuthRequestPKCE)
}
