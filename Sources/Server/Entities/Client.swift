import Foundation

enum ClientError: Error {
    case clientHasNoTenant
    case illegalRedirect(redirect: String, reason: String = "LOGIN.ERRORS.REDIRECT_MISMATCH")
    case illegalReferer(referer: String, reason: String = "LOGIN.ERRORS.WRONG_REFERER")
}

protocol ClientProtocol {
    /// Display name of the client
    var name: String { get }

    /// Configuration of the client
    var config: ClientSpec { get }
}

protocol ClientIdProtocol {
    /// The object must have a known public identifier provided in the `client_id` property.
    var client_id: String { get }
}

/// Concrete Implementation of a client id parameter
struct ClientIdParameter: ClientIdProtocol, Decodable {
    var client_id: String
}

typealias UitsmijterClient = Client

/// A single client that is allowed to access a grant
///
/// Only known clients should communicate with the authorisation server. Clients are mostly defined on
/// the administrative interface of the authorisation server and are stored in some persistence.
public struct Client: ClientProtocol {
    /// Reference to the original resource
    var ref: EntityResourceReference?

    /// Display name of the client
    let name: String

    /// Configuration of the client
    let config: ClientSpec

}

/// Configuration of a Client
struct ClientSpec: Codable {
    /// A unique Ident of the client
    let ident: UUID

    /// This is a client for a specific tenet
    let tenantname: String
    var tenant: Tenant? {
        get {
            Log.info("Try to find tenant with name: \(tenantname)")
            return Tenant.find(name: tenantname)
        }
    }

    /// A list of regular expressions to allow redirect urls
    ///
    /// If the requested `redirect_url` of an `AuthRequest` does not match any of these url patterns, that the whole
    /// authorization request will deny.
    ///
    /// - Note: try to avoid a pattern like `*`, because this is highly insecure. Try to describe the clients domains
    ///          very precisely. eg: `https://[^\.]+\.example\.com/login_(granted|denied)`
    let redirect_urls: [String]

    /// A list of allowed grant types
    ///
    /// If not set, a default set will be applied:
    /// - authorization_code
    /// - refresh_token
    var grant_types: [GrantTypes]? = [.authorization_code, .refresh_token]

    /// A list of allowed scopes for this client
    let scopes: [String]?

    /// A list of concrete referrers that are allowed to request a authorisation.
    /// Leave this blank to allow any referrer.
    let referrers: [String]?

    var secret: String?

    var isPkceOnly: Bool? = false
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

/// Extend the Tenant to be Hashable
///
extension Client: Hashable {
    /// Hashable implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
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
