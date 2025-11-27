import Foundation
import Yams

/// The types of entities that can be managed by the EntityStorage system.
///
/// Uitsmijter supports two primary entity types:
/// - Tenants: Organizations or domains that contain one or more clients
/// - Clients: OAuth2 applications that belong to a tenant
///
/// These entity types form the core domain model for multi-tenant OAuth2 authorization.
enum ManagedEntityType: Sendable {
    /// A tenant entity representing an organization or domain
    case tenant

    /// A client entity representing an OAuth2 application
    case client
}

/// Protocol that all loadable entities must conform to.
///
/// Entities in Uitsmijter are configuration objects loaded from YAML sources,
/// which can be either file-based or Kubernetes Custom Resource Definitions (CRDs).
/// This protocol defines the minimum contract for entity loading and tracking.
///
/// ## Entity Lifecycle
///
/// 1. YAML content is loaded from a file or Kubernetes
/// 2. The entity is initialized with the YAML content and a reference
/// 3. The entity is stored in ``EntityStorage``
/// 4. The entity can be updated if the source changes (hot-reload)
/// 5. The entity can be removed if the source is deleted
///
/// ## Example
///
/// ```swift
/// struct MyEntity: Entity {
///     let name: String
///     var ref: EntityResourceReference?
///
///     init(yaml: String) throws {
///         // Parse YAML and initialize
///     }
///
///     init(yaml: String, ref: EntityResourceReference) throws {
///         try self.init(yaml: yaml)
///         self.ref = ref
///     }
/// }
/// ```
///
/// - SeeAlso: ``Tenant``, ``UitsmijterClient``, ``EntityStorage``
protocol Entity {
    /// The unique name of this entity.
    ///
    /// The name is used for identification and lookup within the system.
    var name: String { get }

    /// A reference to the resource from which this entity was loaded.
    ///
    /// This reference is used for hot-reloading when the source changes,
    /// and for tracking which entities came from which sources.
    var ref: EntityResourceReference? { get set }

    /// Initialize an entity from YAML content.
    ///
    /// - Parameter yaml: The YAML content string to parse
    /// - Throws: YAML parsing errors or validation errors
    init(yaml: String) throws

    /// Initialize an entity from YAML content with a resource reference.
    ///
    /// - Parameters:
    ///   - yaml: The YAML content string to parse
    ///   - ref: The reference to the source of this YAML
    /// - Throws: YAML parsing errors or validation errors
    init(yaml: String, ref: EntityResourceReference) throws
}

/// Protocol for entities that can be found by resource reference.
///
/// This protocol is used by the entity loading system to find and update
/// existing entities when their source files change. Entities that support
/// hot-reloading should conform to this protocol.
///
/// - Important: This protocol requires `@MainActor` isolation to ensure
///   thread-safe access to the ``EntityStorage``.
@MainActor
protocol EntityFindResourceReferenceProtocol {
    /// Find an entity in storage by its resource reference.
    ///
    /// - Parameters:
    ///   - storage: The entity storage to search
    ///   - ref: The resource reference to search for
    /// - Returns: The entity if found, `nil` otherwise
    static func find(in storage: EntityStorage, ref: EntityResourceReference) -> Entity?
}

/// A reference to the source from which an entity was loaded.
///
/// Uitsmijter supports loading entities from two types of sources:
/// - File system YAML files
/// - Kubernetes Custom Resource Definitions (CRDs)
///
/// This enumeration tracks which source an entity came from, enabling
/// hot-reload functionality when sources change.
///
/// ## File References
///
/// File references point to a YAML file on disk. When the file changes,
/// the FileMonitor detects the change and reloads the entity.
///
/// ```swift
/// let ref = EntityResourceReference.file(URL(fileURLWithPath: "/path/to/tenant.yaml"))
/// ```
///
/// ## Kubernetes References
///
/// Kubernetes references track a CRD by its UUID and optionally its resource version.
/// When the CRD changes in the cluster, the Kubernetes watch detects it and reloads the entity.
///
/// ```swift
/// let ref = EntityResourceReference.kubernetes(uuid, revision: "12345")
/// ```
///
/// ## Equality Semantics
///
/// Resource references have special equality semantics:
/// - File references are equal if their URLs match
/// - Kubernetes references are equal if their UUIDs match, ignoring empty revisions
/// - File references are never equal to Kubernetes references
///
/// - SeeAlso: ``Entity``, ``EntityStorage``
enum EntityResourceReference: Codable, Equatable, Sendable {
    /// A reference to a file on the local filesystem
    case file(URL)

    /// A reference to a Kubernetes Custom Resource
    ///
    /// - Parameters:
    ///   - UUID: The unique identifier of the Kubernetes resource
    ///   - String?: The resource version (optional)
    case kubernetes(UUID, String? = nil)

    /// A human-readable description of this resource reference.
    ///
    /// For file references, returns the file path.
    /// For Kubernetes references, returns the UUID and revision.
    var description: String {
        get {
            switch self {
            case .file(let url):
                return url.path
            case .kubernetes(let uuid, let revision):
                return "\(uuid.uuidString) (\(revision ?? ""))"
            }
        }
    }
    
    /// Returns `true` if this is a Kubernetes resource reference
    var isKubernetes: Bool {
        if case .kubernetes = self {
            return true
        }
        return false
    }

    /// Compare resource references with special handling for Kubernetes revisions.
    ///
    /// This custom equality implementation handles the following cases:
    /// - File references are equal if their URLs match exactly
    /// - Kubernetes references are equal if their UUIDs match, with special handling for revisions
    /// - A `nil` revision in either reference means "any revision matches"
    /// - File and Kubernetes references are never equal to each other
    ///
    /// ## Revision Matching Logic
    ///
    /// When comparing Kubernetes references:
    /// - If either reference has a `nil` revision, the comparison ignores revisions
    /// - If both have non-nil revisions, they must match exactly
    /// - This allows finding entities by UUID without knowing the exact revision
    ///
    /// ## Example
    ///
    /// ```swift
    /// let ref1 = EntityResourceReference.kubernetes(uuid, revision: "123")
    /// let ref2 = EntityResourceReference.kubernetes(uuid, revision: nil)
    /// ref1 == ref2  // true - nil revision matches any revision
    ///
    /// let ref3 = EntityResourceReference.kubernetes(uuid, revision: "123")
    /// let ref4 = EntityResourceReference.kubernetes(uuid, revision: "456")
    /// ref3 == ref4  // false - different revisions
    /// ```
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side resource reference
    ///   - rhs: The right-hand side resource reference
    /// - Returns: `true` if the references are considered equal, `false` otherwise
    static func == (lhs: EntityResourceReference, rhs: EntityResourceReference) -> Bool {
        // Compare .file with .file
        if case .file(let lFile) = lhs,
           case .file(let rFile) = rhs {
            return lFile == rFile
        }

        // Compare .kubernetes with .kubernetes
        if case .kubernetes(let lhsUuid, let lhsRevision) = lhs,
           case .kubernetes(let rhsUuid, let rhsRevision) = rhs {
            return lhsUuid == rhsUuid && (
                lhsRevision == nil
                    || rhsRevision == nil
                    || (lhsRevision == rhsRevision)
            )
        }

        // .file != .kubernetes
        return false
    }


}
