import Foundation
import Vapor
import Redis

struct AuthSessionDelegate: RedisSessionsDelegate {

    func redis<Client>(
            _ client: Client,
            store data: SessionData,
            with key: RedisKey
    ) -> EventLoopFuture<Void> where Client: RedisClient {
        // stores each data field as a separate hash field
        var mdata = data
        mdata["updated"] = Date().rfc1123

        let saveFuture = client.hmset(mdata.snapshot, in: key)
        saveFuture.whenSuccess { _ in
            // get the value of the session if it contains a "ttl" string
            let sessionValueContainsTtl: String? =
                    data.snapshot
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
                    Log.info("Store short live session [\(key)] with ttl of \(ttl) seconds")
                    _ = client.expire(key, after: .seconds(ttl))
                }
            } catch {
                Log.error("Can not parse ttl from session value \(data.snapshot). \(error.localizedDescription)")
                return
            }

        }
        return saveFuture

    }

    func redis<Client>(
            _ client: Client,
            fetchDataFor key: RedisKey
    ) -> EventLoopFuture<SessionData?> where Client: RedisClient {
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
