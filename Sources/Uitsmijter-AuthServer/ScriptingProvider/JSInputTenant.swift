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
///     const tenantId = credentials.tenant.id; // null for file-based tenants
///     // … call the external user service scoped to this tenant …
///   }
/// }
/// ```
struct JSInputTenant: Codable, Sendable {
    /// The tenant's unique name (always present).
    let name: String

    /// The tenant's resource identifier. This is the Kubernetes CRD UID when the
    /// tenant is loaded from a CRD, and `nil` for file-based tenants (which have
    /// no stable id — identify those by ``name``).
    let id: String?

    /// Create the tenant context from explicit values.
    init(name: String, id: String? = nil) {
        self.name = name
        self.id = id
    }

    /// Build the tenant context from a loaded ``Tenant``.
    init(from tenant: Tenant) {
        self.name = tenant.name
        if case .kubernetes(let uuid, _) = tenant.ref {
            self.id = uuid.uuidString
        } else {
            self.id = nil
        }
    }
}
