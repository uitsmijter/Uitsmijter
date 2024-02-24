import Foundation
import Redis

class RedisAuthCodeStorage: AuthCodeStorageProtocol {
    /// Injected redis client
    let redis: RedisClient

    init(_ client: RedisClient) {
        redis = client
    }

    // MARK: - AuthCodeStorageProtocol

    func set(authSession session: AuthSession) throws {
        guard let key = RedisKey(rawValue: "\(session.type)~" + session.code.value) else {
            throw AuthCodeStorageError.KEY_ERROR
        }

        let sessionData = try JSONEncoder.main.encode(session)
        try redis.set(key, to: String(data: sessionData, encoding: .utf8)).wait()        

        if let ttl = session.ttl {
            _ = redis.expire(key, after: TimeAmount.seconds(ttl))
        }
    }

    func get(type: AuthSession.CodeType, codeValue value: String, remove: Bool? = false) -> AuthSession? {
        guard let key = RedisKey(rawValue: "\(type)~" + value) else {
            return nil
        }
        let value = try? redis.get(key).wait()
        if remove ?? false {
            _ = redis.delete([key])
        }
        if let data = value?.data {
            do {
                let decoded = try JSONDecoder.main.decode(AuthSession.self, from: data)
                return decoded
            } catch {
                Log.error("\(error.localizedDescription)")
            }
        } else {
            Log.error("Can not get data from code value")
        }
        return nil
    }

    func count(completion: @escaping (Int) -> Void) {
        redis.scan(startingFrom: 0).whenSuccess { _, keys in
            completion(keys.count)
        }
    }

    func push(loginId session: LoginSession) throws {
        guard let key = RedisKey(rawValue: "loginid~" + session.loginId.uuidString) else {
            throw AuthCodeStorageError.KEY_ERROR
        }
        let sessionData = try JSONEncoder.main.encode(session)
        try redis.set(key, to: String(data: sessionData, encoding: .utf8)).wait()
        _ = redis.expire(key, after: TimeAmount.seconds(60 * 120))
    }

    func pull(loginUuid uuid: UUID) -> Bool {
        guard let key = RedisKey(rawValue: "loginid~" + uuid.uuidString) else {
            return false
        }
        guard let value = try? redis.get(key).wait() else {
            return false
        }
        _ = redis.delete([key])

        guard let data = value.data else {
            return false
        }
        if let sessionData = try? JSONDecoder.main.decode(LoginSession.self, from: data) {
            return sessionData.loginId == uuid
        }

        return false
    }

    func delete(type: AuthSession.CodeType, codeValue value: String) throws {
        guard let key = RedisKey(rawValue: "\(type)~" + value) else {
            return
        }
        _ = try redis.delete(key).wait()
    }

    func wipe(tenant: Tenant, subject: String) {
        DispatchQueue.init(
                label: "wipe-tokens.uitsmijter.io",
                qos: .background,
                attributes: .concurrent
        ).async { [self] in
            do {
                let (_, keys) = try redis.scan(startingFrom: 0).wait()
                Log.info("Check \(keys.count) tokens for retention")
                let keysToDelete = try keys.compactMap { key in
                    if let rKey = RedisKey(rawValue: key) {
                        let value = try? redis.get(rKey).wait()
                        if let data = value?.data {
                            let decoded = try JSONDecoder.main.decode(AuthSession.self, from: data)
                            if decoded.payload?.tenant == tenant.name && decoded.payload?.subject.value == subject {
                                return rKey
                            }
                        }
                    }
                    return nil
                }
                Log.info("\(keysToDelete.count) Tokens to delete.")
                _ = try redis.delete(keysToDelete).wait()
            } catch {
                Log.error("Can not get all redis keys. \(error)")
            }
        }
    }

    func isHealthy() -> Bool {
        if (try? redis.ping().wait()) == "PONG" {
            Log.info("Redis is healthy")
            return true
        }

        Log.error("Redis is not healthy")
        return false
    }
}
