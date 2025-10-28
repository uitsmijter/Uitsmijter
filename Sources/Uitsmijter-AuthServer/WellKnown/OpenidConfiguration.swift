import Foundation

// swiftlint:disable identifier_name
/// OpenID Connect Discovery 1.0 Provider Metadata.
///
/// This structure represents the complete discovery metadata for an OpenID Provider
/// as specified in [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata).
///
/// The metadata is served at `/.well-known/openid-configuration` and allows clients
/// to automatically discover the provider's capabilities and endpoints.
///
/// ## Multi-Tenant Support
///
/// In Uitsmijter's multi-tenant architecture, each tenant can have different
/// configuration values (issuer, scopes, grant types, etc.). This structure
/// can be populated with tenant-specific values.
///
/// ## Required vs Optional Fields
///
/// - **REQUIRED**: Must always be present in the discovery document
/// - **RECOMMENDED**: Should be present for full OIDC compliance
/// - **OPTIONAL**: May be included based on provider capabilities
///
/// - SeeAlso: [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata)
struct OpenidConfiguration: Codable, Sendable {

    // MARK: - Required Fields

    /// REQUIRED. URL using the https scheme with no query or fragment component that the OP asserts as its
    /// Issuer Identifier.
    ///
    /// This value MUST be identical to the `iss` claim value in ID Tokens issued from this issuer.
    /// In multi-tenant mode, this will be the tenant-specific issuer URL.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com"
    /// ```
    public let issuer: String

    /// REQUIRED. URL of the OP's OAuth 2.0 Authorization Endpoint.
    ///
    /// Clients use this endpoint to obtain authorization from the resource owner.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/authorize"
    /// ```
    public let authorization_endpoint: String

    /// REQUIRED unless only the Implicit Flow is used. URL of the OP's OAuth 2.0 Token Endpoint.
    ///
    /// Clients use this endpoint to exchange authorization codes for access tokens.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/token"
    /// ```
    public let token_endpoint: String?

    /// REQUIRED. URL of the OP's JWK Set document.
    ///
    /// This contains the signing keys used to validate ID Tokens. The JWK Set may also contain
    /// the server's encryption keys.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/.well-known/jwks.json"
    /// ```
    public let jwks_uri: String

    /// REQUIRED. JSON array containing a list of the OAuth 2.0 response_type values that this OP supports.
    ///
    /// Dynamic OpenID Providers MUST support the `code`, `id_token`, and `token id_token` response types.
    ///
    /// ## Example
    ///
    /// ```
    /// ["code", "code id_token", "id_token", "token id_token"]
    /// ```
    public let response_types_supported: [String]

    /// REQUIRED. JSON array containing a list of Subject Identifier types that this OP supports.
    ///
    /// Valid types are `pairwise` and `public`.
    ///
    /// ## Example
    ///
    /// ```
    /// ["public"]
    /// ```
    public let subject_types_supported: [String]

    /// REQUIRED. JSON array containing a list of JWS signing algorithms (alg values) supported
    /// by the OP for the ID Token.
    ///
    /// The value `none` MUST NOT be used.
    ///
    /// ## Example
    ///
    /// ```
    /// ["RS256", "ES256"]
    /// ```
    public let id_token_signing_alg_values_supported: [String]

    // MARK: - Recommended Fields

    /// RECOMMENDED. URL of the OP's UserInfo Endpoint.
    ///
    /// Clients use this endpoint to obtain claims about the authenticated end-user.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/userinfo"
    /// ```
    public let userinfo_endpoint: String?

    /// RECOMMENDED. URL of the OP's Dynamic Client Registration Endpoint.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/register"
    /// ```
    public let registration_endpoint: String?

    /// RECOMMENDED. JSON array containing a list of the OAuth 2.0 scope values that this server supports.
    ///
    /// Servers MAY choose not to advertise some supported scope values.
    ///
    /// ## Example
    ///
    /// ```
    /// ["openid", "profile", "email", "address", "phone"]
    /// ```
    public let scopes_supported: [String]?

    /// RECOMMENDED. JSON array containing a list of the Claim Names of the Claims that the
    /// OpenID Provider MAY be able to supply values for.
    ///
    /// ## Example
    ///
    /// ```
    /// ["sub", "name", "email", "email_verified", "picture"]
    /// ```
    public let claims_supported: [String]?

    // MARK: - Optional Fields

    /// OPTIONAL. JSON array containing a list of the OAuth 2.0 response_mode values that this OP supports.
    ///
    /// If omitted, the default is `["query", "fragment"]`.
    ///
    /// ## Example
    ///
    /// ```
    /// ["query", "fragment", "form_post"]
    /// ```
    public let response_modes_supported: [String]?

    /// OPTIONAL. JSON array containing a list of the OAuth 2.0 grant type values that this OP supports.
    ///
    /// If omitted, the default value is `["authorization_code", "implicit"]`.
    ///
    /// ## Example
    ///
    /// ```
    /// ["authorization_code", "refresh_token", "client_credentials"]
    /// ```
    public let grant_types_supported: [String]?

    /// OPTIONAL. JSON array containing a list of the Authentication Context Class References that this OP supports.
    ///
    /// ## Example
    ///
    /// ```
    /// ["urn:mace:incommon:iap:silver", "urn:mace:incommon:iap:bronze"]
    /// ```
    public let acr_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of Client Authentication methods supported by this Token Endpoint.
    ///
    /// If omitted, the default is `client_secret_basic`.
    ///
    /// ## Example
    ///
    /// ```
    /// ["client_secret_post", "client_secret_basic", "private_key_jwt"]
    /// ```
    public let token_endpoint_auth_methods_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWS signing algorithms supported by the
    /// Token Endpoint for the signature on the JWT used to authenticate the client.
    ///
    /// ## Example
    ///
    /// ```
    /// ["RS256", "ES256"]
    /// ```
    public let token_endpoint_auth_signing_alg_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of display parameter values that the OP supports.
    ///
    /// ## Example
    ///
    /// ```
    /// ["page", "popup", "touch", "wap"]
    /// ```
    public let display_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of Claim Types that the OP supports.
    ///
    /// If omitted, the default is `normal`.
    ///
    /// ## Example
    ///
    /// ```
    /// ["normal", "aggregated", "distributed"]
    /// ```
    public let claim_types_supported: [String]?

    /// OPTIONAL. URL that the OP provides to the person registering the Client to read about the OP's
    /// requirements on how the Relying Party can use the data provided by the OP.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/about/policy"
    /// ```
    public let service_documentation: String?

    /// OPTIONAL. Languages and scripts supported for values in Claims being returned.
    ///
    /// ## Example
    ///
    /// ```
    /// ["en-US", "en-GB", "de-DE"]
    /// ```
    public let claims_locales_supported: [String]?

    /// OPTIONAL. Languages and scripts supported for the user interface.
    ///
    /// ## Example
    ///
    /// ```
    /// ["en-US", "de-DE", "fr-FR"]
    /// ```
    public let ui_locales_supported: [String]?

    /// OPTIONAL. Boolean value specifying whether the OP supports use of the claims parameter.
    ///
    /// If omitted, the default value is `false`.
    public let claims_parameter_supported: Bool?

    /// OPTIONAL. Boolean value specifying whether the OP supports use of the request parameter.
    ///
    /// If omitted, the default value is `false`.
    public let request_parameter_supported: Bool?

    /// OPTIONAL. Boolean value specifying whether the OP supports use of the request_uri parameter.
    ///
    /// If omitted, the default value is `true`.
    public let request_uri_parameter_supported: Bool?

    /// OPTIONAL. Boolean value specifying whether the OP requires any request_uri values
    /// used to be pre-registered.
    ///
    /// If omitted, the default value is `false`.
    public let require_request_uri_registration: Bool?

    /// OPTIONAL. URL that the OP provides to the person registering the Client to read about
    /// the OP's policy regarding use of data.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/privacy"
    /// ```
    public let op_policy_uri: String?

    /// OPTIONAL. URL that the OP provides to the person registering the Client to read about
    /// the OP's terms of service.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/terms"
    /// ```
    public let op_tos_uri: String?

    /// OPTIONAL. URL of the OP's Revocation Endpoint.
    ///
    /// ## Example
    ///
    /// ```
    /// "https://auth.example.com/revoke"
    /// ```
    public let revocation_endpoint: String?

    /// OPTIONAL. JSON array containing a list of JWS encoding algorithms supported for
    /// UserInfo responses.
    ///
    /// ## Example
    ///
    /// ```
    /// ["RS256", "ES256", "HS256"]
    /// ```
    public let userinfo_signing_alg_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWE encryption algorithms (alg values)
    /// supported for UserInfo responses.
    ///
    /// ## Example
    ///
    /// ```
    /// ["RSA-OAEP", "A256KW"]
    /// ```
    public let userinfo_encryption_alg_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWE encryption algorithms (enc values)
    /// supported for UserInfo responses.
    ///
    /// ## Example
    ///
    /// ```
    /// ["A256GCM", "A128CBC-HS256"]
    /// ```
    public let userinfo_encryption_enc_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWE encryption algorithms (alg values)
    /// supported for ID Tokens.
    ///
    /// ## Example
    ///
    /// ```
    /// ["RSA-OAEP", "A256KW"]
    /// ```
    public let id_token_encryption_alg_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWE encryption algorithms (enc values)
    /// supported for ID Tokens.
    ///
    /// ## Example
    ///
    /// ```
    /// ["A256GCM", "A128CBC-HS256"]
    /// ```
    public let id_token_encryption_enc_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWS signing algorithms supported for
    /// Request Objects.
    ///
    /// ## Example
    ///
    /// ```
    /// ["RS256", "ES256"]
    /// ```
    public let request_object_signing_alg_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWE encryption algorithms (alg values)
    /// supported for Request Objects.
    ///
    /// ## Example
    ///
    /// ```
    /// ["RSA-OAEP", "A256KW"]
    /// ```
    public let request_object_encryption_alg_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of JWE encryption algorithms (enc values)
    /// supported for Request Objects.
    ///
    /// ## Example
    ///
    /// ```
    /// ["A256GCM", "A128CBC-HS256"]
    /// ```
    public let request_object_encryption_enc_values_supported: [String]?

    /// OPTIONAL. JSON array containing a list of Proof Key for Code Exchange (PKCE) code challenge methods supported.
    ///
    /// ## Example
    ///
    /// ```
    /// ["plain", "S256"]
    /// ```
    public let code_challenge_methods_supported: [String]?

    // MARK: - Initialization

    /// Initialize OpenID Configuration with all fields.
    ///
    /// - Parameters:
    ///   - issuer: REQUIRED. The issuer identifier
    ///   - authorization_endpoint: REQUIRED. Authorization endpoint URL
    ///   - token_endpoint: Token endpoint URL (required unless only using Implicit Flow)
    ///   - jwks_uri: REQUIRED. JWK Set document URL
    ///   - response_types_supported: REQUIRED. Supported response types
    ///   - subject_types_supported: REQUIRED. Supported subject identifier types
    ///   - id_token_signing_alg_values_supported: REQUIRED. Supported ID Token signing algorithms
    ///   - userinfo_endpoint: RECOMMENDED. UserInfo endpoint URL
    ///   - registration_endpoint: RECOMMENDED. Dynamic registration endpoint URL
    ///   - scopes_supported: RECOMMENDED. Supported scopes
    ///   - claims_supported: RECOMMENDED. Claims that may be supplied
    ///   - response_modes_supported: OPTIONAL. Supported response modes
    ///   - grant_types_supported: OPTIONAL. Supported grant types
    ///   - acr_values_supported: OPTIONAL. Supported ACR values
    ///   - token_endpoint_auth_methods_supported: OPTIONAL. Supported token endpoint auth methods
    ///   - token_endpoint_auth_signing_alg_values_supported: OPTIONAL. Supported signing algorithms for token endpoint auth
    ///   - display_values_supported: OPTIONAL. Supported display values
    ///   - claim_types_supported: OPTIONAL. Supported claim types
    ///   - service_documentation: OPTIONAL. Service documentation URL
    ///   - claims_locales_supported: OPTIONAL. Supported locales for claims
    ///   - ui_locales_supported: OPTIONAL. Supported UI locales
    ///   - claims_parameter_supported: OPTIONAL. Whether claims parameter is supported
    ///   - request_parameter_supported: OPTIONAL. Whether request parameter is supported
    ///   - request_uri_parameter_supported: OPTIONAL. Whether request_uri parameter is supported
    ///   - require_request_uri_registration: OPTIONAL. Whether request_uri pre-registration is required
    ///   - op_policy_uri: OPTIONAL. OP policy URL
    ///   - op_tos_uri: OPTIONAL. OP terms of service URL
    ///   - revocation_endpoint: OPTIONAL. Token revocation endpoint URL
    ///   - userinfo_signing_alg_values_supported: OPTIONAL. Supported UserInfo signing algorithms
    ///   - userinfo_encryption_alg_values_supported: OPTIONAL. Supported UserInfo encryption algorithms (alg)
    ///   - userinfo_encryption_enc_values_supported: OPTIONAL. Supported UserInfo encryption algorithms (enc)
    ///   - id_token_encryption_alg_values_supported: OPTIONAL. Supported ID Token encryption algorithms (alg)
    ///   - id_token_encryption_enc_values_supported: OPTIONAL. Supported ID Token encryption algorithms (enc)
    ///   - request_object_signing_alg_values_supported: OPTIONAL. Supported Request Object signing algorithms
    ///   - request_object_encryption_alg_values_supported: OPTIONAL. Supported Request Object encryption algorithms (alg)
    ///   - request_object_encryption_enc_values_supported: OPTIONAL. Supported Request Object encryption algorithms (enc)
    ///   - code_challenge_methods_supported: OPTIONAL. Supported PKCE code challenge methods
    public init(
        issuer: String,
        authorization_endpoint: String,
        token_endpoint: String?,
        jwks_uri: String,
        response_types_supported: [String],
        subject_types_supported: [String],
        id_token_signing_alg_values_supported: [String],
        userinfo_endpoint: String? = nil,
        registration_endpoint: String? = nil,
        scopes_supported: [String]? = nil,
        claims_supported: [String]? = nil,
        response_modes_supported: [String]? = nil,
        grant_types_supported: [String]? = nil,
        acr_values_supported: [String]? = nil,
        token_endpoint_auth_methods_supported: [String]? = nil,
        token_endpoint_auth_signing_alg_values_supported: [String]? = nil,
        display_values_supported: [String]? = nil,
        claim_types_supported: [String]? = nil,
        service_documentation: String? = nil,
        claims_locales_supported: [String]? = nil,
        ui_locales_supported: [String]? = nil,
        claims_parameter_supported: Bool? = nil,
        request_parameter_supported: Bool? = nil,
        request_uri_parameter_supported: Bool? = nil,
        require_request_uri_registration: Bool? = nil,
        op_policy_uri: String? = nil,
        op_tos_uri: String? = nil,
        revocation_endpoint: String? = nil,
        userinfo_signing_alg_values_supported: [String]? = nil,
        userinfo_encryption_alg_values_supported: [String]? = nil,
        userinfo_encryption_enc_values_supported: [String]? = nil,
        id_token_encryption_alg_values_supported: [String]? = nil,
        id_token_encryption_enc_values_supported: [String]? = nil,
        request_object_signing_alg_values_supported: [String]? = nil,
        request_object_encryption_alg_values_supported: [String]? = nil,
        request_object_encryption_enc_values_supported: [String]? = nil,
        code_challenge_methods_supported: [String]? = nil
    ) {
        self.issuer = issuer
        self.authorization_endpoint = authorization_endpoint
        self.token_endpoint = token_endpoint
        self.jwks_uri = jwks_uri
        self.response_types_supported = response_types_supported
        self.subject_types_supported = subject_types_supported
        self.id_token_signing_alg_values_supported = id_token_signing_alg_values_supported
        self.userinfo_endpoint = userinfo_endpoint
        self.registration_endpoint = registration_endpoint
        self.scopes_supported = scopes_supported
        self.claims_supported = claims_supported
        self.response_modes_supported = response_modes_supported
        self.grant_types_supported = grant_types_supported
        self.acr_values_supported = acr_values_supported
        self.token_endpoint_auth_methods_supported = token_endpoint_auth_methods_supported
        self.token_endpoint_auth_signing_alg_values_supported = token_endpoint_auth_signing_alg_values_supported
        self.display_values_supported = display_values_supported
        self.claim_types_supported = claim_types_supported
        self.service_documentation = service_documentation
        self.claims_locales_supported = claims_locales_supported
        self.ui_locales_supported = ui_locales_supported
        self.claims_parameter_supported = claims_parameter_supported
        self.request_parameter_supported = request_parameter_supported
        self.request_uri_parameter_supported = request_uri_parameter_supported
        self.require_request_uri_registration = require_request_uri_registration
        self.op_policy_uri = op_policy_uri
        self.op_tos_uri = op_tos_uri
        self.revocation_endpoint = revocation_endpoint
        self.userinfo_signing_alg_values_supported = userinfo_signing_alg_values_supported
        self.userinfo_encryption_alg_values_supported = userinfo_encryption_alg_values_supported
        self.userinfo_encryption_enc_values_supported = userinfo_encryption_enc_values_supported
        self.id_token_encryption_alg_values_supported = id_token_encryption_alg_values_supported
        self.id_token_encryption_enc_values_supported = id_token_encryption_enc_values_supported
        self.request_object_signing_alg_values_supported = request_object_signing_alg_values_supported
        self.request_object_encryption_alg_values_supported = request_object_encryption_alg_values_supported
        self.request_object_encryption_enc_values_supported = request_object_encryption_enc_values_supported
        self.code_challenge_methods_supported = code_challenge_methods_supported
    }
}
// swiftlint:enable identifier_name
