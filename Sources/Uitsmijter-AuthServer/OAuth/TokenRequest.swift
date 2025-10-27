import Foundation

/// Protocol defining the common structure for all OAuth 2.0 token requests.
///
/// This protocol establishes the baseline requirements for token request types,
/// ensuring all grant type implementations include the essential OAuth 2.0 parameters.
///
/// ## Required Parameters
///
/// - **grant_type**: Identifies which OAuth flow is being used
/// - **client_id**: Identifies the application making the request
/// - **client_secret**: Optional secret for confidential clients
///
/// - Note: Conforms to `Sendable` for Swift 6 concurrency safety.
/// - SeeAlso: ``GrantTypes`` for supported grant types
public protocol TokenRequestProtocol: Codable, Sendable {

    /// The OAuth 2.0 grant type being requested.
    ///
    /// Determines which authentication flow and validation rules apply.
    var grant_type: GrantTypes { get }

    /// The client identifier registered with the authorization server.
    ///
    /// This uniquely identifies the application making the token request.
    var client_id: String { get }

    /// The client secret for confidential clients.
    ///
    /// Required for confidential clients, optional for public clients.
    /// Used to authenticate the client application to the authorization server.
    var client_secret: String? { get }
}

/// Basic OAuth 2.0 token request structure.
///
/// This struct represents a generic token request with minimal parameters.
/// It's used for grant types that don't require additional fields beyond
/// the basic OAuth 2.0 requirements.
///
/// ## Example
///
/// ```swift
/// let request = TokenRequest(
///     grant_type: .authorization_code,
///     client_id: "my-app-id",
///     client_secret: "secret123",
///     scope: "read write"
/// )
/// ```
///
/// - Note: For authorization code flows, use ``CodeTokenRequest`` instead.
/// - SeeAlso: ``CodeTokenRequest`` for authorization code grant
/// - SeeAlso: ``RefreshTokenRequest`` for refresh token grant
/// - SeeAlso: ``PasswordTokenRequest`` for password grant
public struct TokenRequest: TokenRequestProtocol, ClientIdProtocol,
    /*RedirectUriProtocol, */  ScopesProtocol, Sendable {

    public var grant_type: GrantTypes

    public var client_id: String

    public var client_secret: String?

    public var scope: String?

    public init(grant_type: GrantTypes, client_id: String, client_secret: String? = nil, scope: String? = nil) {
        self.grant_type = grant_type
        self.client_id = client_id
        self.client_secret = client_secret
        self.scope = scope
    }
}

/// OAuth 2.0 authorization code grant token request with PKCE support.
///
/// This struct represents a token request for the authorization code flow,
/// including optional PKCE (Proof Key for Code Exchange) parameters for
/// enhanced security in public clients.
///
/// ## Authorization Code Flow
///
/// 1. Client redirects user to authorization endpoint
/// 2. User authenticates and authorizes the client
/// 3. Server redirects back with authorization code
/// 4. Client exchanges code for access token using this request
///
/// ## PKCE Extension
///
/// PKCE adds cryptographic protection against authorization code interception:
/// - Client generates random `code_verifier`
/// - Client derives `code_challenge` from verifier
/// - Authorization request includes `code_challenge`
/// - Token request includes `code_verifier` for verification
///
/// ## Example
///
/// ```swift
/// // Without PKCE
/// let request = CodeTokenRequest(
///     grant_type: .authorization_code,
///     client_id: "my-app",
///     code: "abc123xyz"
/// )
///
/// // With PKCE
/// let request = CodeTokenRequest(
///     grant_type: .authorization_code,
///     client_id: "my-app",
///     code: "abc123xyz",
///     code_challenge_method: .S256,
///     code_verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
/// )
/// ```
///
/// - Note: PKCE is recommended for all clients and required for public clients.
/// - SeeAlso: [RFC 7636 - PKCE](https://tools.ietf.org/html/rfc7636)
/// - SeeAlso: ``CodeChallengeMethod`` for challenge methods
public struct CodeTokenRequest: TokenRequestProtocol, Sendable {

    // MARK: - Protocol Implementation

    /// The grant type, must be `.authorization_code`.
    public var grant_type: GrantTypes

    /// The client identifier.
    public var client_id: String

    /// The client secret (required for confidential clients).
    public var client_secret: String?

    /// The requested OAuth scopes.
    public var scope: String?

    // MARK: - Code Implementation

    /// The authorization code received from the authorization endpoint.
    ///
    /// This short-lived code is exchanged for an access token.
    public let code: Code.StringLiteralType

    /// The method used to generate the code challenge.
    ///
    /// If using PKCE, this must match the method used in the authorization request.
    /// Common values: `.plain` or `.S256` (SHA-256).
    public var code_challenge_method: CodeChallengeMethod?

    /// The PKCE code verifier string.
    ///
    /// The server will hash this value and compare it to the `code_challenge`
    /// provided in the authorization request to verify the exchange.
    public var code_verifier: String?

    public init(
        grant_type: GrantTypes,
        client_id: String,
        client_secret: String? = nil,
        scope: String? = nil,
        code: Code.StringLiteralType,
        code_challenge_method: CodeChallengeMethod? = nil,
        code_verifier: String? = nil
    ) {
        self.grant_type = grant_type
        self.client_id = client_id
        self.client_secret = client_secret
        self.scope = scope
        self.code = code
        self.code_challenge_method = code_challenge_method
        self.code_verifier = code_verifier
    }
}

import CryptoSwift

public extension CodeTokenRequest {
    /// The SHA-256 hash in Base64 of the original code_verifier
    ///
    /// code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
    ///
    /// - SeeAlso:
    ///   - codeChallenge
    var code_challenge: String? {
        get {
            if let code_verifier {
                return code_verifier.data(using: .ascii)?.sha256().base64String()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            }
            return nil
        }
    }
}

public struct RefreshTokenRequest: TokenRequestProtocol, Sendable {

    public var grant_type: GrantTypes

    public var client_id: String

    public var client_secret: String?

    // MARK: - Refresh Token Implementation

    public let refresh_token: String

    public init(grant_type: GrantTypes, client_id: String, client_secret: String? = nil, refresh_token: String) {
        self.grant_type = grant_type
        self.client_id = client_id
        self.client_secret = client_secret
        self.refresh_token = refresh_token
    }
}

public struct PasswordTokenRequest: TokenRequestProtocol, Sendable {

    // MARK: - Protocol Implementation

    public var grant_type: GrantTypes

    public var client_id: String

    public var client_secret: String?

    public var scope: String?

    // MARK: - Code Implementation

    public let username: String

    public let password: String

    public init(
        grant_type: GrantTypes, client_id: String, client_secret: String? = nil,
        scope: String? = nil, username: String, password: String
    ) {
        self.grant_type = grant_type
        self.client_id = client_id
        self.client_secret = client_secret
        self.scope = scope
        self.username = username
        self.password = password
    }
}
