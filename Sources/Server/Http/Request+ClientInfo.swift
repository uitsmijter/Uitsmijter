import Foundation
import Vapor

struct ClientInfoRequest: Codable {
    let scheme: String
    let host: String
    let uri: String

    var description: String {
        get {
            "\(scheme)://\(host)\(uri)"
        }
    }
}

struct ClientInfo: Codable {
    let mode: LoginMode
    let requested: ClientInfoRequest
    let referer: String?
    let responsibleDomain: String
    let serviceUrl: String

    var tenant: Tenant?
    var client: Client?
    var expired: Bool?
    var subject: String?

    var validPayload: Payload?

    func isExpired() -> Bool {
        expired ?? true
    }
}

struct ClientInfoKey: StorageKey {
    typealias Value = ClientInfo
}

extension Request {
    var clientInfo: ClientInfo? {
        get {
            storage[ClientInfoKey.self]
        }
        set {
            storage[ClientInfoKey.self] = newValue
        }
    }
}
