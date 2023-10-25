import Foundation
import Vapor

struct RequestInfo: Codable {
    var description: String
}

struct RequestInfoKey: StorageKey {
    typealias Value = RequestInfo
}

extension Request {
    var requestInfo: RequestInfo? {
        get {
            storage[RequestInfoKey.self]
        }
        set {
            storage[RequestInfoKey.self] = newValue
        }
    }
}
