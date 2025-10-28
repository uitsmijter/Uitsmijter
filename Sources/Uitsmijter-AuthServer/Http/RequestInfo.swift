import Foundation

/// Request information that can be passed through the request chain
struct RequestInfo: Codable, Sendable {
    var description: String

    init(description: String) {
        self.description = description
    }
}
