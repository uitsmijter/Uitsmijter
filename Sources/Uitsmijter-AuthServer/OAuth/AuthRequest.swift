import Foundation

/// A protocol that all OAuth2 authorization requests must implement.
///
/// This protocol defines the required properties for initiating an OAuth2
/// authorization flow, combining client identification, redirect URIs,
/// scopes, and response type requirements.
///
/// ## Topics
///
/// ### Protocol Requirements
/// - ``response_type``
/// - ``client_id``
/// - ``client_secret``
/// - ``redirect_uri``
/// - ``scope``
/// - ``state``
/// - ``redirectPath``
///
/// ## See Also
/// - ``AuthRequest``
/// - ``AuthRequestPKCE``
/// - ``AuthRequests``
public protocol AuthRequestProtocol: Codable, ClientIdProtocol, RedirectUriProtocol, ScopesProtocol, Sendable {

    /// The type of response expected from the authorization server.
    ///
    /// Indicates what type of response the client expects. Typically `.code`
    /// for the authorization code flow.
    ///
    /// - SeeAlso: ``ResponseType``
    var response_type: ResponseType { get }

    /// The public identifier for the client application.
    ///
    /// The application must be registered with the authorization server
    /// and this identifier must match a known client.
    var client_id: String { get }

    /// Optional secret for authenticating the client.
    ///
    /// Some clients (confidential clients) may provide a secret for
    /// additional authentication. Public clients (like mobile apps)
    /// typically do not use a client secret.
    var client_secret: String? { get }

    /// The URI where the authorization server will redirect after authorization.
    ///
    /// This URI must match one of the redirect URIs registered for the client.
    /// The authorization server will reject requests with unregistered URIs.
    var redirect_uri: URL { get }

    /// Space-delimited list of requested access scopes.
    ///
    /// Defines the level of access being requested. The authorization server
    /// will display these scopes to the user during authorization.
    var scope: String? { get }

    /// Opaque value used to maintain state between request and callback.
    ///
    /// The client should use this parameter to prevent CSRF attacks and to
    /// maintain request-specific state. The authorization server returns this
    /// value unchanged in the response.
    var state: String { get }
}

/// Default implementations for all authorization requests.
public extension AuthRequestProtocol {
    /// The path component of the redirect URI.
    ///
    /// Extracts just the path portion from the full redirect URI.
    /// For example, from `https://example.com/callback?foo=bar`,
    /// this returns `/callback`.
    var redirectPath: String {
        redirect_uri.path
    }
}

/// A standard OAuth2 authorization request.
///
/// Represents a basic authorization code flow request without PKCE.
/// This is suitable for confidential clients (like server-side applications)
/// that can securely store a client secret.
///
/// ## Example
///
/// ```swift
/// let authRequest = AuthRequest(
///     response_type: .code,
///     client_id: "BCB2E4D2-4DCD-4D14-877B-397FB8490411",
///     redirect_uri: URL(string: "https://mysite.example.com")!,
///     scope: "read write",
///     state: "aiZeij6t"
/// )
/// ```
///
/// ## See Also
/// - ``AuthRequestPKCE`` for PKCE-enabled requests
/// - ``AuthRequestProtocol``
public struct AuthRequest: AuthRequestProtocol {
    /// The type of requested response, typically `.code`.
    public var response_type: ResponseType

    /// The client identifier registered with the authorization server.
    public var client_id: String

    /// Optional client secret for confidential clients.
    public var client_secret: String?

    /// The URI where the authorization response will be sent.
    public var redirect_uri: URL

    /// Space-delimited list of requested scopes.
    public var scope: String?

    /// Opaque state value to prevent CSRF attacks.
    public var state: String

    /// Creates a new authorization request.
    ///
    /// - Parameters:
    ///   - response_type: The type of response expected (typically `.code`)
    ///   - client_id: The client identifier
    ///   - client_secret: Optional client secret for authentication
    ///   - redirect_uri: Where to redirect after authorization
    ///   - scope: Optional space-delimited scopes
    ///   - state: State value for CSRF protection
    public init(
        response_type: ResponseType,
        client_id: String,
        client_secret: String? = nil,
        redirect_uri: URL,
        scope: String? = nil,
        state: String
    ) {
        self.response_type = response_type
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri
        self.scope = scope
        self.state = state
    }
}

/// An OAuth2 authorization request with PKCE (Proof Key for Code Exchange).
///
/// PKCE adds an additional layer of security to the authorization code flow,
/// making it suitable for public clients (like mobile and single-page applications)
/// that cannot securely store a client secret.
///
/// The client generates a random `code_verifier` (43-128 characters), then
/// computes a `code_challenge` from it using the specified method.
///
/// ## Example
///
/// ```swift
/// let authRequest = AuthRequestPKCE(
///     response_type: .code,
///     client_id: "BCB2E4D2-4DCD-4D14-877B-397FB8490411",
///     redirect_uri: URL(string: "https://mysite.example.com")!,
///     scope: "read write",
///     state: "aiZeij6t",
///     code_challenge: "E9Melhoa20wvFrEMTJguCHaoeK1t8URWbuGjSstw-CM",
///     code_challenge_method: .sha256
/// )
/// ```
///
/// ## See Also
/// - ``AuthRequest`` for requests without PKCE
/// - ``CodeChallengeMethod``
/// - ``AuthRequestProtocol``
public struct AuthRequestPKCE: AuthRequestProtocol {
    /// The type of requested response, typically `.code`.
    public var response_type: ResponseType

    /// The client identifier registered with the authorization server.
    public var client_id: String

    /// Optional client secret (typically not used with PKCE).
    public var client_secret: String?

    /// The URI where the authorization response will be sent.
    public var redirect_uri: URL

    /// Space-delimited list of requested scopes.
    public var scope: String?

    /// Opaque state value to prevent CSRF attacks.
    public var state: String

    /// The code challenge derived from the code verifier.
    ///
    /// This is computed from a random `code_verifier` string (43-128 characters)
    /// using the method specified in `code_challenge_method`.
    ///
    /// For SHA256:
    /// ```
    /// code_challenge = base64urlEncode(SHA256(ASCII(code_verifier)))
    /// ```
    public let code_challenge: String

    /// The method used to derive the code challenge from the code verifier.
    ///
    /// Typically `.sha256` for maximum security, or `.plain` if SHA256
    /// is not available.
    ///
    /// - SeeAlso: ``CodeChallengeMethod``
    public let code_challenge_method: CodeChallengeMethod

    /// Creates a new PKCE authorization request.
    ///
    /// - Parameters:
    ///   - response_type: The type of response expected (typically `.code`)
    ///   - client_id: The client identifier
    ///   - client_secret: Optional client secret (rarely used with PKCE)
    ///   - redirect_uri: Where to redirect after authorization
    ///   - scope: Optional space-delimited scopes
    ///   - state: State value for CSRF protection
    ///   - code_challenge: The challenge derived from the code verifier
    ///   - code_challenge_method: The method used to derive the challenge
    public init(
        response_type: ResponseType,
        client_id: String,
        client_secret: String? = nil,
        redirect_uri: URL,
        scope: String? = nil,
        state: String,
        code_challenge: String,
        code_challenge_method: CodeChallengeMethod
    ) {
        self.response_type = response_type
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri
        self.scope = scope
        self.state = state
        self.code_challenge = code_challenge
        self.code_challenge_method = code_challenge_method
    }
}

/// An enum wrapping different types of authorization requests.
///
/// This enum provides a type-safe way to handle both standard and
/// PKCE-enabled authorization requests.
///
/// ## Topics
///
/// ### Cases
/// - ``insecure(_:)``
/// - ``pkce(_:)``
///
/// ## See Also
/// - ``AuthRequest``
/// - ``AuthRequestPKCE``
public enum AuthRequests: Sendable {
    /// A standard authorization request without PKCE.
    ///
    /// Suitable for confidential clients that can securely store credentials.
    ///
    /// - Parameter request: The authorization request
    case insecure(AuthRequest)

    /// A PKCE-enabled authorization request.
    ///
    /// Recommended for public clients like mobile and single-page applications.
    ///
    /// - Parameter request: The PKCE authorization request
    case pkce(AuthRequestPKCE)
}
