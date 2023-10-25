import Foundation

protocol TimeToLiveProtocol {
    var ttl: Int64? { get }
}

struct TimeToLive: TimeToLiveProtocol, Decodable {
    var ttl: Int64?
}
