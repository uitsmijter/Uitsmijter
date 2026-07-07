import Foundation

/// Tenant context passed into the JavaScript provider alongside the credentials.
///
/// Exposed to provider scripts as the `tenant` property of the constructor argument,
/// so a provider (e.g. one talking to Uitrusting) can scope its request to the
/// correct tenant:
///
/// ```javascript
/// class UserLoginProvider {
///   constructor(credentials) {
///     const tenantName = credentials.tenant.name;
///     const tenantNamespace = credentials.tenant.namespace; // null for file-based tenants
///     // … call the external user service scoped to this tenant …
///   }
/// }
/// ```
struct JSInputTenant: Codable, Sendable {
    /// The tenant's name (without the namespace prefix).
    let name: String

    /// The Kubernetes namespace the tenant is defined in.
    ///
    /// `nil` for file-based tenants, which have no namespace. CRD tenants are stored
    /// internally as `"<namespace>/<name>"`; this splits that back into its parts.
    let namespace: String?

    /// Create the tenant context from explicit values.
    init(name: String, namespace: String? = nil) {
        self.name = name
        self.namespace = namespace
    }

    /// Build the tenant context from a loaded ``Tenant``.
    ///
    /// CRD tenants carry a `"<namespace>/<name>"` name; file-based tenants carry a
    /// plain name and therefore have no namespace.
    init(from tenant: Tenant) {
        let parts = tenant.name.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            self.namespace = String(parts[0])
            self.name = String(parts[1])
        } else {
            self.namespace = nil
            self.name = tenant.name
        }
    }
}
