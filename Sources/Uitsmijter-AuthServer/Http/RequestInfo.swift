import Foundation

/// Request information that can be passed through the request chain
public struct RequestInfo: Codable, Sendable {
    public var description: String

    public init(description: String) {
        self.description = description
    }
}
