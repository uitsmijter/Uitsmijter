import Foundation
import Redis

enum AuthCodeStorageImplementations {
    case memory
    case redis(client: RedisClient)
    case custom(implementation: AuthCodeStorageProtocol)
}
