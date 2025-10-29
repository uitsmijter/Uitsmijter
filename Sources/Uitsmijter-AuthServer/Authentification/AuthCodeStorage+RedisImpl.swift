import Foundation
@preconcurrency import Redis
import Logger

/// Actor-based thread-safe Redis storage for authorization codes and login sessions
/// Converted from @unchecked Sendable to proper Actor isolation per ACTOR.md recommendations
actor RedisAuthCodeStorage: AuthCodeStorageProtocol {
    /// Injected redis client
    let redis: RedisClient

    init(_ client: RedisClient) {
        redis = client
    }

    // MARK: - AuthCodeStorageProtocol

    func set(authSession session: AuthSession) async throws {
        guard let key = RedisKey(rawValue: "\(session.type)~" + session.code.value) else {
            throw AuthCodeStorageError.KEY_ERROR
        }

        let sessionData = try JSONEncoder.main.encode(session)
        try await redis.set(key, to: String(data: sessionData, encoding: .utf8)).get()

        if let ttl = session.ttl {
            _ = try await redis.expire(key, after: TimeAmount.seconds(ttl)).get()
        }
    }

    func get(type: AuthSession.CodeType, codeValue value: String, remove: Bool? = false) async -> AuthSession? {
        guard let key = RedisKey(rawValue: "\(type)~" + value) else {
            return nil
        }
        let value = try? await redis.get(key).get()
        if remove ?? false {
            _ = try? await redis.delete([key]).get()
        }
        if let data = value?.data {
            do {
                let decoded = try JSONDecoder.main.decode(AuthSession.self, from: data)
                return decoded
            } catch {
                Log.error("\(error.localizedDescription)")
            }
        } else {
            Log.error("Cannot get data from code value")
        }
        return nil
    }

    func count() async -> Int {
        do {
            let (_, keys) = try await redis.scan(startingFrom: 0).get()
            return keys.count
        } catch {
            Log.error("Failed to count redis keys: \(error)")
            return 0
        }
    }

    func push(loginId session: LoginSession) async throws {
        guard let key = RedisKey(rawValue: "loginid~" + session.loginId.uuidString) else {
            throw AuthCodeStorageError.KEY_ERROR
        }

        let sessionData = try JSONEncoder.main.encode(session)
        let stringValue = String(data: sessionData, encoding: .utf8)

        try await redis.set(key, to: stringValue).get()
        _ = try await redis.expire(key, after: TimeAmount.seconds(60 * 120)).get()
    }

    func pull(loginUuid uuid: UUID) async -> Bool {
        guard let key = RedisKey(rawValue: "loginid~" + uuid.uuidString) else {
            return false
        }

        guard let value = try? await redis.get(key).get() else {
            return false
        }

        return await processValue(value, uuid: uuid, key: key)
    }

    private func processValue(_ value: RESPValue, uuid: UUID, key: RedisKey) async -> Bool {
        _ = try? await redis.delete([key]).get()

        guard let data = value.data else {
            return false
        }

        if let sessionData = try? JSONDecoder.main.decode(LoginSession.self, from: data) {
            return sessionData.loginId == uuid
        }

        return false
    }

    func delete(type: AuthSession.CodeType, codeValue value: String) async throws {
        guard let key = RedisKey(rawValue: "\(type)~" + value) else {
            return
        }
        _ = try await redis.delete(key).get()
    }

    func wipe(tenant: Tenant, subject: String) async {
        do {
            let (_, keys) = try await redis.scan(startingFrom: 0).get()
            let keysToDelete: [RedisKey] = try await withThrowingTaskGroup(of: RedisKey?.self) { group in
                for key in keys {
                    group.addTask {
                        if let rKey = RedisKey(rawValue: key) {
                            let value = try? await self.redis.get(rKey).get()
                            if let data = value?.data {
                                let decoded = try JSONDecoder.main.decode(AuthSession.self, from: data)
                                if decoded.payload?.tenant == tenant.name && decoded.payload?.subject.value == subject {
                                    return rKey
                                }
                            }
                        }
                        return nil
                    }
                }

                var result: [RedisKey] = []
                for try await key in group {
                    if let key = key {
                        result.append(key)
                    }
                }
                return result
            }
            if !keysToDelete.isEmpty {
                _ = try await redis.delete(keysToDelete).get()
            }
        } catch {
            Log.error("Cannot get all redis keys. \(error)")
        }
    }

    func isHealthy() async -> Bool {
        if (try? await redis.ping().get()) == "PONG" {
            return true
        }

        Log.error("Redis is not healthy")
        return false
    }
}
