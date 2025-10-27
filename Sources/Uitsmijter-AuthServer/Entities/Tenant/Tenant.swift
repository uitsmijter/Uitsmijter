import Foundation

/// Base protocol that all tenant implementations must conform to.
///
/// This protocol defines the minimum contract for tenant entities,
/// ensuring they have a name and configuration regardless of implementation.
public protocol TenantProtocol {
    /// The unique display name of the tenant.
    ///
    /// This name is used for identification and must be unique across all tenants.
    var name: String { get }

    /// The configuration specification for this tenant.
    ///
    /// Contains hosts, settings, and provider configurations.
    var config: TenantSpec { get }
}

/// Optional informational URLs for a tenant.
///
/// These URLs provide links to legal and registration pages that can be
/// displayed in the login UI. All fields are optional to allow tenants
/// to provide only the information relevant to them.
///
/// ## Example YAML Configuration
///
/// ```yaml
/// informations:
///   imprint_url: "https://example.com/imprint"
///   privacy_url: "https://example.com/privacy"
///   register_url: "https://example.com/register"
/// ```
///
/// - SeeAlso: ``TenantSpec``
public struct TenantInformations: Codable, Sendable {
    /// URL to the legal imprint page.
    ///
    /// Typically required in certain jurisdictions (e.g., Germany's "Impressum").
    public let imprint_url: String?

    /// URL to the privacy policy page.
    ///
    /// Should explain how user data is collected, used, and protected.
    public let privacy_url: String?

    /// URL to the user registration page.
    ///
    /// Allows new users to create accounts if self-registration is enabled.
    public let register_url: String?

    /// Initialize tenant informational URLs.
    ///
    /// - Parameters:
    ///   - imprint_url: Optional URL to imprint page
    ///   - privacy_url: Optional URL to privacy policy
    ///   - register_url: Optional URL to registration page
    public init(imprint_url: String? = nil, privacy_url: String? = nil, register_url: String? = nil) {
        self.imprint_url = imprint_url
        self.privacy_url = privacy_url
        self.register_url = register_url
    }
}

/// Configuration for Traefik ForwardAuth interceptor mode.
///
/// When interceptor mode is enabled, Uitsmijter acts as a Traefik ForwardAuth
/// middleware, protecting routes by validating authentication before allowing
/// access to upstream services.
///
/// ## How Interceptor Mode Works
///
/// 1. Traefik receives a request to a protected route
/// 2. Traefik forwards the request to Uitsmijter via ForwardAuth
/// 3. Uitsmijter checks if the user is authenticated
/// 4. If authenticated, Uitsmijter returns 200 and Traefik allows the request
/// 5. If not authenticated, Uitsmijter redirects to the login page
///
/// ## Example YAML Configuration
///
/// ```yaml
/// interceptor:
///   enabled: true
///   domain: "login.example.com"
///   cookie: ".example.com"  # Optional: share cookies across subdomains
/// ```
///
/// - SeeAlso: ``TenantSpec``
public struct TenantInterceptorSettings: Codable, Sendable {
    /// Whether interceptor mode is enabled for this tenant.
    ///
    /// When `true`, this tenant can be used with Traefik ForwardAuth.
    public let enabled: Bool

    /// The login domain for this interceptor.
    ///
    /// This is the domain where the login page will be hosted.
    /// For example: `login.example.com`
    public let domain: String?

    /// Optional specific cookie domain for this interceptor.
    ///
    /// If set, cookies will be scoped to this domain instead of `domain`.
    /// Use a leading dot to share cookies across subdomains: `.example.com`
    public var cookie: String?

    /// The domain to use for setting cookies.
    ///
    /// Returns `cookie` if set, otherwise falls back to `domain`.
    /// This allows fine-grained control over cookie scoping.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let settings = TenantInterceptorSettings(
    ///     enabled: true,
    ///     domain: "login.example.com",
    ///     cookie: ".example.com"
    /// )
    /// print(settings.cookieOrDomain)  // ".example.com"
    /// ```
    public var cookieOrDomain: String? {
        get {
            cookie ?? domain
        }
    }

    /// Initialize interceptor settings.
    ///
    /// - Parameters:
    ///   - enabled: Whether interceptor mode is enabled
    ///   - domain: The login domain (e.g., "login.example.com")
    ///   - cookie: Optional specific cookie domain (e.g., ".example.com")
    public init(enabled: Bool, domain: String? = nil, cookie: String? = nil) {
        self.enabled = enabled
        self.domain = domain
        self.cookie = cookie
    }
}

/// Configuration for loading tenant-specific templates from S3-compatible storage.
///
/// Uitsmijter supports customizing login/logout templates per tenant by loading
/// them from S3-compatible object storage. This allows each tenant to have
/// completely customized branding and user experience.
///
/// ## Supported Storage Providers
///
/// - Amazon S3
/// - MinIO
/// - Backblaze B2
/// - Any S3-compatible storage
///
/// ## Template Structure
///
/// Templates are loaded from the bucket at the specified path. The structure should be:
/// ```
/// bucket/path/
///   login.leaf
///   logout.leaf
///   error.leaf
/// ```
///
/// ## Example YAML Configuration
///
/// ```yaml
/// templates:
///   access_key_id: "AKIAIOSFODNN7EXAMPLE"
///   secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
///   bucket: "uitsmijter-templates"
///   host: "https://s3.amazonaws.com"
///   path: "tenants/acme"
///   region: "us-east-1"
/// ```
///
/// - SeeAlso: ``TenantSpec``
public struct TenantTemplatesSettings: Codable, Sendable {
    /// S3 access key ID or account name.
    ///
    /// Used for authenticating with the S3-compatible storage service.
    public var access_key_id: String

    /// S3 secret access key or password.
    ///
    /// Used for authenticating with the S3-compatible storage service.
    /// - Warning: This should be kept secure and not logged or exposed.
    public var secret_access_key: String

    /// The S3 bucket name where templates are stored.
    ///
    /// For example: `"uitsmijter-templates"`
    public var bucket: String

    /// The S3 host endpoint URL.
    ///
    /// Defaults to AWS S3. For other providers:
    /// - MinIO: `"https://minio.example.com"`
    /// - Backblaze: `"https://s3.us-west-002.backblazeb2.com"`
    public var host: String = "https://s3.amazonaws.com"

    /// The path within the bucket where templates are located.
    ///
    /// For example: `"tenants/acme"` would look for templates at
    /// `bucket/tenants/acme/login.leaf`, etc.
    public var path: String = ""

    /// The AWS region name.
    ///
    /// For AWS S3, use regions like `"us-east-1"`, `"eu-west-1"`, etc.
    /// For other providers, consult their documentation.
    public var region: String = "us-east-1"

    /// Initialize S3 template storage settings.
    ///
    /// - Parameters:
    ///   - access_key_id: S3 access key ID
    ///   - secret_access_key: S3 secret access key
    ///   - bucket: S3 bucket name
    ///   - host: S3 host endpoint (defaults to AWS S3)
    ///   - path: Path within bucket (defaults to root)
    ///   - region: AWS region (defaults to us-east-1)
    public init(
        access_key_id: String,
        secret_access_key: String,
        bucket: String,
        host: String = "https://s3.amazonaws.com",
        path: String = "",
        region: String = "us-east-1"
    ) {
        self.access_key_id = access_key_id
        self.secret_access_key = secret_access_key
        self.bucket = bucket
        self.host = host
        self.path = path
        self.region = region
    }
}

/// Type alias for backward compatibility.
public typealias UitsmijterTenant = Tenant

/// A tenant represents an organization or domain in the Uitsmijter system.
///
/// Tenants are the top-level organizational entity in Uitsmijter's multi-tenant
/// architecture. Each tenant can have multiple OAuth2 clients, custom branding,
/// and its own authentication providers.
///
/// ## Tenant Identification
///
/// Tenants are identified by matching the request's `Host` header or
/// `X-Forwarded-Host` header against the tenant's configured hosts.
/// Wildcard patterns are supported for flexible host matching.
///
/// ## Multi-Tenancy Architecture
///
/// ```
/// Tenant: Acme Corp
/// ├─ Hosts: ["acme.com", "*.acme.com"]
/// ├─ Clients:
/// │  ├─ Web App (client_id: "web-app")
/// │  └─ Mobile App (client_id: "mobile-app")
/// └─ Providers: ["ldap-provider.js"]
/// ```
///
/// ## Example YAML Configuration
///
/// ```yaml
/// name: acme-corp
/// config:
///   hosts:
///     - "acme.com"
///     - "*.acme.com"
///   informations:
///     imprint_url: "https://acme.com/imprint"
///     privacy_url: "https://acme.com/privacy"
///   interceptor:
///     enabled: true
///     domain: "login.acme.com"
///   providers:
///     - "ldap-provider.js"
///   silent_login: true
/// ```
///
/// ## Hot-Reloading
///
/// Tenants support hot-reloading from their source files or Kubernetes CRDs.
/// When a tenant YAML file changes, the EntityLoader automatically updates
/// the tenant in ``EntityStorage``.
///
/// - SeeAlso: ``TenantSpec``, ``UitsmijterClient``, ``EntityStorage``
public struct Tenant: TenantProtocol, Sendable {
    /// Reference to the source from which this tenant was loaded.
    ///
    /// Used for hot-reloading when the source changes.
    public var ref: EntityResourceReference?

    /// The unique name of this tenant.
    ///
    /// Used for identification and lookup within the system.
    public let name: String

    /// The configuration specification for this tenant.
    ///
    /// Contains all tenant settings including hosts, providers, and features.
    public let config: TenantSpec

    /// Initialize a tenant with explicit values.
    ///
    /// - Parameters:
    ///   - ref: Optional reference to the source resource
    ///   - name: Unique tenant name
    ///   - config: Tenant configuration specification
    public init(ref: EntityResourceReference? = nil, name: String, config: TenantSpec) {
        self.ref = ref
        self.name = name
        self.config = config
    }
}

/// Complete configuration specification for a tenant.
///
/// This structure contains all the settings and features that can be
/// configured for a tenant, loaded from YAML or Kubernetes CRDs.
///
/// - SeeAlso: ``Tenant``
public struct TenantSpec: Codable, Sendable {
    /// List of hosts that this tenant serves.
    ///
    /// Requests are matched against these hosts to determine which tenant
    /// should handle them. Supports wildcard patterns like `*.example.com`.
    ///
    /// ## Example
    ///
    /// ```yaml
    /// hosts:
    ///   - "example.com"
    ///   - "*.example.com"
    ///   - "app.example.org"
    /// ```
    public let hosts: [String]

    /// Optional informational URLs for legal and registration pages.
    ///
    /// These URLs are made available to templates for display in the UI.
    public var informations: TenantInformations?

    /// Configuration for Traefik ForwardAuth interceptor mode.
    ///
    /// When enabled, this tenant can be used with Traefik to protect routes.
    public var interceptor: TenantInterceptorSettings?

    /// List of JavaScript provider files for this tenant.
    ///
    /// Providers implement authentication logic against existing user databases.
    /// File paths are relative to the providers directory.
    ///
    /// ## Example
    ///
    /// ```yaml
    /// providers:
    ///   - "ldap-auth.js"
    ///   - "custom-db.js"
    /// ```
    public var providers: [String] = []

    /// Configuration for loading templates from S3-compatible storage.
    ///
    /// When set, tenant-specific templates are loaded from S3 instead of
    /// the default file system templates.
    public var templates: TenantTemplatesSettings?

    /// Whether silent login is enabled for this tenant.
    ///
    /// When `true`, users can be authenticated without showing the login form
    /// if they have a valid session. Defaults to `true`.
    ///
    /// Set to `false` to always show the login form, even for authenticated users.
    public var silent_login: Bool? = true

    /// Initialize a tenant specification.
    ///
    /// - Parameters:
    ///   - hosts: List of hosts this tenant serves
    ///   - informations: Optional informational URLs
    ///   - interceptor: Optional interceptor mode configuration
    ///   - providers: List of provider file paths
    ///   - templates: Optional S3 template configuration
    ///   - silent_login: Whether silent login is enabled (defaults to true)
    public init(
        hosts: [String],
        informations: TenantInformations? = nil,
        interceptor: TenantInterceptorSettings? = nil,
        providers: [String] = [],
        templates: TenantTemplatesSettings? = nil,
        silent_login: Bool? = true
    ) {
        self.hosts = hosts
        self.informations = informations
        self.interceptor = interceptor
        self.providers = providers
        self.templates = templates
        self.silent_login = silent_login
    }
}

/// Extend Tenant to conform to Hashable for use in collections.
///
/// Tenants are identified by their unique name, which is used for
/// equality comparison and hashing.
extension Tenant: Hashable {
    /// Compare two tenants for equality.
    ///
    /// Tenants are considered equal if they have the same name.
    /// This allows storing tenants in a `Set` with automatic deduplication.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side tenant
    ///   - rhs: The right-hand side tenant
    /// - Returns: `true` if both tenants have the same name
    public static func == (lhs: Tenant, rhs: Tenant) -> Bool {
        lhs.name == rhs.name
    }

    /// Generate a hash value for this tenant.
    ///
    /// The hash is based solely on the tenant name, matching the
    /// equality implementation.
    ///
    /// - Parameter hasher: The hasher to use for combining values
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// Extend TenantSpec to conform to Equatable and Hashable.
///
/// Tenant specifications are identified by their hosts configuration,
/// which must be unique across all tenants.
extension TenantSpec: Equatable, Hashable {
    /// Compare two tenant specifications for equality.
    ///
    /// Specifications are considered equal if they have the same hosts.
    /// This enforces the constraint that host lists must be unique.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side specification
    ///   - rhs: The right-hand side specification
    /// - Returns: `true` if both specifications have the same hosts
    public static func == (lhs: TenantSpec, rhs: TenantSpec) -> Bool {
        lhs.hosts == rhs.hosts
    }

    /// Generate a hash value for this tenant specification.
    ///
    /// The hash is based solely on the hosts list, matching the
    /// equality implementation.
    ///
    /// - Parameter hasher: The hasher to use for combining values
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hosts)
    }
}

import Yams

/// Extend Tenant to support YAML encoding/decoding and Entity protocol.
///
/// This extension enables tenants to be loaded from YAML files or Kubernetes
/// CRDs, and to be serialized back to YAML format when needed.
extension Tenant: Decodable, Encodable, Entity {
    /// Initialize a tenant from YAML content.
    ///
    /// This initializer parses YAML content and creates a tenant instance.
    /// It's used by the EntityLoader when loading tenants from files or
    /// Kubernetes resources.
    ///
    /// ## Example YAML
    ///
    /// ```yaml
    /// name: acme-corp
    /// config:
    ///   hosts:
    ///     - "acme.com"
    ///     - "*.acme.com"
    ///   providers:
    ///     - "ldap-provider.js"
    /// ```
    ///
    /// - Parameter yaml: The YAML content string to parse
    /// - Throws: `DecodingError` if the YAML is invalid or missing required fields
    public init(yaml: String) throws {
        let decoder = YAMLDecoder()
        self = try decoder.decode(Tenant.self, from: yaml)
    }

    /// Initialize a tenant from YAML content with a resource reference.
    ///
    /// This initializer is used when loading tenants from specific sources
    /// (files or Kubernetes) where we need to track the source for hot-reloading.
    ///
    /// - Parameters:
    ///   - yaml: The YAML content string to parse
    ///   - ref: The resource reference to associate with this tenant
    /// - Throws: `DecodingError` if the YAML is invalid or missing required fields
    public init(yaml: String, ref: EntityResourceReference) throws {
        self = try Tenant(yaml: yaml)
        self.ref = ref
    }

    /// Serialize this tenant to YAML format.
    ///
    /// Converts the tenant back to YAML for debugging, logging, or export.
    ///
    /// - Returns: The YAML representation, or `nil` if encoding fails
    var yaml: String? {
        get {
            let encoder = YAMLEncoder()
            return try? encoder.encode(self)
        }
    }

    /// Serialize this tenant to YAML with indentation.
    ///
    /// Creates an indented YAML representation, useful for nested output
    /// or pretty-printing in logs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let tenant = Tenant(name: "acme", config: spec)
    /// print(tenant.yaml(indent: 2))
    /// // Output:
    /// //   name: acme
    /// //   config:
    /// //     hosts:
    /// //       - acme.com
    /// ```
    ///
    /// - Parameter indent: The number of spaces to prefix each line with
    /// - Returns: The indented YAML representation
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
