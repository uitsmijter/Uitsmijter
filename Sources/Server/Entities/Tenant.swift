import Foundation

/// All tenants have to implement `TenantProtocol` across all implementations
protocol TenantProtocol {
    /// Display name of the tenant
    var name: String { get }

    /// Configuration of the tenant
    var config: TenantSpec { get }
}

/// Informations about a `Tenant`
struct TenantInformations: Codable {
    /// Imprint URL
    let imprint_url: String?

    /// Privacy policy URL
    let privacy_url: String?

    /// Registration URL
    let register_url: String?
}

/// Interceptor-Mode settings of a `Tenant`
struct TenantInterceptorSettings: Codable {
    /// Is the Interceptor-Mode enabled?
    let enabled: Bool

    /// What is login domain for this interceptor?
    let domain: String?

    /// The optional specific cookie domain for this interceptor
    var cookie: String?

    /// returns the domain for the cookie to set.
    /// If a specific cookie domain is set, than this is used. Otherwise the login domain for the interceptor is used.
    var cookieOrDomain: String? {
        get {
            cookie ?? domain
        }
    }
}

/// S3 setting to load template files from
struct TenantTemplatesSettings: Codable {
    // S3 access key id / account name
    var access_key_id: String
    // S3 access key secret / password
    var secret_access_key: String
    // S3 bucket name
    var bucket: String
    // S3 host name
    var host: String = "https://s3.amazonaws.com"
    // S3 path
    var path: String = ""
    // S3 region name
    var region: String = "us-east-1"
}

typealias UitsmijterTenant = Tenant

/// A tenant is the top most ordering entity. A tenant can have multiple clients that are allowed to make a login
/// request. A tenant is known by a list of hosts that must match the referer and `X-Forwarded-Host` header.
struct Tenant: TenantProtocol {
    /// Reference to the original resource
    var ref: EntityResourceReference?

    /// Display name of the tenant
    let name: String

    /// Configuration of the tenant
    let config: TenantSpec
}

/// Configuration of a Tenant
struct TenantSpec: Codable {
    /// A list of concrete hosts for which the server serves the tenant.
    let hosts: [String]

    /// Further informations about the tenant
    var informations: TenantInformations?

    /// If interceptor is allowed?
    var interceptor: TenantInterceptorSettings?

    /// Tenant provided plugin providers
    var providers: [String] = []

    /// Tenant template config
    var templates: TenantTemplatesSettings?

   /// Enable silent login
    var silent_login: Bool? = true
}

/// Extend the Tenant to be hashable
extension Tenant: Hashable {
    /// Are two tenants identical?
    ///
    /// - Parameters:
    ///   - lhs: One tenant to compare the the other tenant
    ///   - rhs: An other tenant
    /// - Returns: True if both tenants are identical
    ///
    static func == (lhs: Tenant, rhs: Tenant) -> Bool {
        lhs.name == rhs.name
    }

    /// Hashable implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// Extend the TenantSpec to be equatable and hashable
extension TenantSpec: Equatable, Hashable {
    /// Are two spects are identical?
    ///
    /// - Parameters:
    ///   - lhs: One TenantSpec to compare the the other TenantSpec
    ///   - rhs: An other TenantSpec
    /// - Returns: True if both specs are identical
    ///
    static func == (lhs: TenantSpec, rhs: TenantSpec) -> Bool {
        lhs.hosts == rhs.hosts
    }

    /// Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(hosts)
    }
}

import Yams

/// Tenant encodable and decodable functions
extension Tenant: Decodable, Encodable, Entity {
    /// Load a tenant from a yaml file
    ///
    /// - Parameter yaml: YAML String of a tenant
    /// - Throws: An error when decoding fails
    init(yaml: String) throws {
        let decoder = YAMLDecoder()
        self = try decoder.decode(Tenant.self, from: yaml)
    }

    /// Load a tenant from a yaml file with a Kubernetes reference
    ///
    /// - Parameter
    ///     - yaml: YAML String of a tenant
    ///     - ref: A Kubernetes `EntityResourceReference`
    /// - Throws: An error when decoding fails
    init(yaml: String, ref: EntityResourceReference) throws {
        self = try Tenant(yaml: yaml)
        self.ref = ref
    }

    /// Get the `Tenant` as yaml
    var yaml: String? {
        get {
            let encoder = YAMLEncoder()
            return try? encoder.encode(self)
        }
    }

    /// Get the `Tenant` as yaml with a indention
    ///
    /// - Parameter indent: Number of spaces for each indent
    /// - Returns: A `yaml` representation of the `Tenant`
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
