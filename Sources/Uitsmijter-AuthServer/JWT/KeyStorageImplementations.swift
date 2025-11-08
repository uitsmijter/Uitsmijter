import Foundation
@preconcurrency import Redis

enum KeyStorageImplementations {
    case memory
    case redis(client: RedisClient)
    case custom(implementation: KeyStorageProtocol)
}
