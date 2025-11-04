import Foundation
import Vapor

struct ForwardInfo {
    let location: URL
}

struct ForwardInfoKey: StorageKey {
    typealias Value = ForwardInfo
}

extension Request {
    var forwardInfo: ForwardInfo? {
        get {
            storage[ForwardInfoKey.self]
        }
        set {
            storage[ForwardInfoKey.self] = newValue
        }
    }
}
