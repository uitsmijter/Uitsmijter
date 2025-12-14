import Foundation
import Logger

/// Type alias for backward compatibility.
typealias UitsmijterClient = Client

/// An OAuth2 client application registered with a tenant.
///
/// Clients represent applications that can request authorization on behalf of users.
/// Each client is associated with a specific tenant and has its own configuration
/// for OAuth2 flows, redirect URIs, scopes, and security settings.
///
/// ## OAuth2 Client Registration
///
/// Clients must be pre-registered with the authorization server, following
/// OAuth 2.0 client registration practices (RFC 6749, Section 2).
///
/// ## Multi-Tenant Architecture
///
/// ```
/// Tenant: Acme Corp
/// └─ Client: Web App
///    ├─ client_id: 550e8400-e29b-41d4-a716-446655440000
///    ├─ redirect_urls: ["https://app.acme.com/callback"]
///    ├─ grant_types: ["authorization_code", "refresh_token"]
///    └─ scopes: ["openid", "profile", "email"]
/// ```
///
/// ## Example YAML Configuration
///
/// ```yaml
/// name: acme-web-app
/// config:
///   ident: 550e8400-e29b-41d4-a716-446655440000
///   tenantname: acme-corp
///   redirect_urls:
///     - "https://app\\.acme\\.com/callback"
///   grant_types:
///     - authorization_code
///     - refresh_token
///   scopes:
///     - openid
///     - profile
///   referrers:
///     - "https://app.acme.com"
///   isPkceOnly: false
/// ```
///
/// ## Security Considerations
///
/// - Redirect URIs use regular expressions for matching but should be as specific as possible
/// - PKCE (Proof Key for Code Exchange) can be enforced via `isPkceOnly`
/// - Client secrets should be kept confidential for confidential clients
/// - Referer validation provides additional origin verification
///
/// - SeeAlso: ``ClientSpec``, ``Tenant``, ``ClientError``
struct Client: ClientProtocol, Sendable {
    /// Reference to the source from which this client was loaded.
    ///
    /// Used for hot-reloading when the source changes.
    var ref: EntityResourceReference?

    /// The unique name of this client.
    ///
    /// Used for identification and logging.
    let name: String

    /// The configuration specification for this client.
    ///
    /// Contains all OAuth2 settings and security constraints.
    let config: ClientSpec

    /// Initialize a client with explicit values.
    ///
    /// - Parameters:
    ///   - ref: Optional reference to the source resource
    ///   - name: Unique client name
    ///   - config: Client configuration specification
    init(ref: EntityResourceReference? = nil, name: String, config: ClientSpec) {
        self.ref = ref
        self.name = name
        self.config = config
    }
}

/// Complete configuration specification for an OAuth2 client.
///
/// Contains all settings required for OAuth2 authorization flows, including
/// security constraints and allowed operations.
///
/// - SeeAlso: ``Client``
struct ClientSpec: Codable, Sendable {
    /// The unique identifier for this client (client_id in OAuth2 terms).
    ///
    /// This UUID is used as the `client_id` parameter in OAuth2 flows.
    let ident: UUID

    /// The name of the tenant this client belongs to.
    ///
    /// Every client must be associated with exactly one tenant.
    let tenantname: String

    /// Regular expression patterns for allowed redirect URIs.
    ///
    /// Per OAuth 2.0 (RFC 6749), redirect URIs must be pre-registered and validated
    /// to prevent authorization code interception attacks.
    ///
    /// ## Security Best Practice
    ///
    /// Use specific patterns rather than wildcards:
    /// - Good: `https://app\\.example\\.com/callback`
    /// - Bad: `.*` (allows any redirect, highly insecure)
    ///
    /// ## Example Patterns
    ///
    /// ```
    /// redirect_urls:
    ///   - "https://app\\.example\\.com/(callback|oauth/callback)"
    ///   - "https://[^.]+\\.example\\.com/auth/complete"
    /// ```
    let redirect_urls: [String]

    /// OAuth2 grant types allowed for this client.
    ///
    /// If not set, defaults to: `["authorization_code", "refresh_token"]`
    ///
    /// Supported grant types:
    /// - `authorization_code`: Standard OAuth2 authorization code flow
    /// - `refresh_token`: Allows token refresh
    /// - `client_credentials`: Service-to-service authentication
    var grant_types: [String]?

    /// OAuth2 scopes allowed for this client.
    ///
    /// Limits what permissions this client can request. Common scopes:
    /// - `openid`: OpenID Connect authentication
    /// - `profile`: User profile information
    /// - `email`: User email address
    let scopes: [String]?

    ///
    /// Limits what provides can push to the users scopes:
    let allowedProviderScopes: [String]?

    /// Allowed HTTP referers for additional origin validation.
    ///
    /// If specified, requests must come from one of these referers.
    /// Leave empty to allow any referer (less secure).
    ///
    /// ## Example
    ///
    /// ```
    /// referrers:
    ///   - "https://app.example.com"
    ///   - "https://admin.example.com"
    /// ```
    let referrers: [String]?

    /// The client secret for confidential clients.
    ///
    /// Required for confidential clients (e.g., server-side applications).
    /// Public clients (e.g., SPAs, mobile apps) should not have a secret.
    ///
    /// - Warning: This should be kept confidential and never exposed to end users.
    var secret: String?

    /// Whether this client requires PKCE (Proof Key for Code Exchange).
    ///
    /// When `true`, PKCE is required for all authorization requests from this client,
    /// providing additional security for public clients (RFC 7636).
    ///
    /// Recommended for: SPAs, mobile apps, and any public client.
    var isPkceOnly: Bool? = false

    /// Initialize a client specification.
    ///
    /// - Parameters:
    ///   - ident: Unique client identifier (UUID)
    ///   - tenantname: Name of the tenant this client belongs to
    ///   - redirect_urls: Regex patterns for allowed redirect URIs
    ///   - grant_types: Allowed OAuth2 grant types
    ///   - scopes: Allowed OAuth2 scopes
    ///   - referrers: Allowed HTTP referers
    ///   - secret: Client secret for confidential clients
    ///   - isPkceOnly: Whether PKCE is required (defaults to false)
    init(
        ident: UUID,
        tenantname: String,
        redirect_urls: [String],
        grant_types: [String]? = nil,
        scopes: [String]? = nil,
        allowedProviderScopes: [String]? = nil,
        referrers: [String]? = nil,
        secret: String? = nil,
        isPkceOnly: Bool? = false
    ) {
        self.ident = ident
        self.tenantname = tenantname
        self.redirect_urls = redirect_urls
        self.grant_types = grant_types
        self.scopes = scopes
        self.allowedProviderScopes = allowedProviderScopes
        self.referrers = referrers
        self.secret = secret
        self.isPkceOnly = isPkceOnly
    }
}

extension ClientSpec: Equatable, Hashable {
    /// Are two clients identical?
    ///
    /// - Parameters:
    ///   - lhs: One client to compare the the other client
    ///   - rhs: An other client
    /// - Returns: True if both clients are identical
    ///
    static func == (lhs: ClientSpec, rhs: ClientSpec) -> Bool {
        lhs.ident == rhs.ident
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ident)
    }
}

import Yams

/// Client from Yaml file
extension Client: Decodable, Encodable, Entity {
    /// Load a client from a yaml file
    ///
    /// - Parameter yaml: YAML String of a client
    /// - Throws: An error when decoding fails
    init(yaml: String) throws {
        let decoder = YAMLDecoder()
        self = try decoder.decode(Client.self, from: yaml)
    }

    init(yaml: String, ref: EntityResourceReference) throws {
        self = try Client(yaml: yaml)
        self.ref = ref
    }

    var yaml: String? {
        get {
            let encoder = YAMLEncoder()
            return try? encoder.encode(self)
        }
    }

    func yaml(indent: Int) -> String {
        let yamlString = yaml
        let linePrefix = String(repeating: " ", count: indent)
        guard let newYaml = yamlString?
                .split(separator: "\n")
                .map({ linePrefix.appending($0) }).joined(separator: "\n")
        else {
            return ""
        }
        return newYaml
    }

}
