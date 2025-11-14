import Foundation
import Vapor
@preconcurrency import Redis
import Logger

/// Delegate for managing user sessions in Redis with TTL support.
///
/// This delegate implements Vapor's `RedisSessionsDelegate` protocol to provide
/// session storage with automatic expiration based on TimeToLive values embedded
/// in session data. Sessions containing TTL information will automatically expire
/// in Redis after the specified duration.
///
/// ## TTL Handling
///
/// When storing session data, the delegate inspects the data for any value containing
/// "ttl". If found, it attempts to decode a `TimeToLive` model and sets the Redis key
/// expiration accordingly. This enables automatic cleanup of short-lived sessions.
///
/// ## Thread Safety
///
/// Uses `UnsafeTransfer` to safely capture non-Sendable Redis types in async contexts
/// while maintaining safety guarantees through Vapor's EventLoop architecture.
struct AuthSessionDelegate: RedisSessionsDelegate {

    func redis<RedisClientType>(
        _ client: RedisClientType,
        store data: SessionData,
        with key: RedisKey
    ) -> EventLoopFuture<Void> where RedisClientType: RedisClient {
        // stores each data field as a separate hash field
        var mdata = data
        mdata["updated"] = Date().rfc1123

        let saveFuture = client.hmset(mdata.snapshot, in: key)
        // RedisClient from external RediStack package isn't Sendable, but this usage is safe
        // Capture as existential to avoid generic type capture
        let clientAsAny: any RedisClient = client
        let unsafeClient = UnsafeTransfer(clientAsAny)
        let unsafeKey = UnsafeTransfer(key)
        let dataSnapshot = data.snapshot
        saveFuture.whenSuccess { @Sendable _ in
            // get the value of the session if it contains a "ttl" string
            let sessionValueContainsTtl: String? =
                dataSnapshot
                .filter { snap in
                    snap.value.contains("ttl")
                }
                .first?.value

            guard let sessionValueContainsTtl = sessionValueContainsTtl,
                  let sessionDataContainsTtl = sessionValueContainsTtl.data(using: .utf8)
            else {
                return
            }

            // Try to decode the model in the session
            do {
                let modelWithTtl = try JSONDecoder.main.decode(TimeToLive.self, from: sessionDataContainsTtl)
                if let ttl = modelWithTtl.ttl {
                    Log.info("Store short live session [\(unsafeKey.wrappedValue)] with ttl of \(ttl) seconds")
                    _ = unsafeClient.wrappedValue.expire(unsafeKey.wrappedValue, after: .seconds(ttl))
                }
            } catch {
                Log.error("Can not parse ttl from session value \(dataSnapshot). \(error.localizedDescription)")
                return
            }

        }
        return saveFuture

    }

    func redis<RedisClientType>(
        _ client: RedisClientType,
        fetchDataFor key: RedisKey
    ) -> EventLoopFuture<SessionData?> where RedisClientType: RedisClient {
        client
            .hgetall(from: key)
            .map { hash in
                // hash is [String: RESPValue] so we need to try and unwrap the
                // value as a string and store each value in the data container
                hash.reduce(into: SessionData()) { result, next in
                    guard let value = next.value.string else {
                        return
                    }
                    result[next.key] = value
                }
            }
    }

    func makeNewID() -> SessionID {
        SessionID(string: UUID().uuidString)
    }

    func makeRedisKey(for sessionID: SessionID) -> RedisKey {
        RedisKey("user~\(sessionID.string)")
    }

}
