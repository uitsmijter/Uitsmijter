import Foundation
import Vapor
import Yams
import Dispatch

/// Definition of global managed entities
enum ManagedEntityType {
    case tenant
    case client
}

/// Every Entity should be decoded from a yaml definition
protocol Entity {
    var name: String { get }
    var ref: EntityResourceReference? { get set }
    init(yaml: String) throws
    init(yaml: String, ref: EntityResourceReference) throws
}

protocol EntityFindResourceReferenceProtocol {
    static func find(ref: EntityResourceReference) -> Entity?
}

enum EntityResourceReference: Codable, Equatable {
    case file(URL)
    case kubernetes(UUID, String? = nil)

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

    /// Compare resource references by ignoring empty k8s revision numbers
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
