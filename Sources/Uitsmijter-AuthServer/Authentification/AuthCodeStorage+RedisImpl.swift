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
            Log.error("DEBUG REDIS: Failed to create RedisKey for loginid: \(session.loginId.uuidString)")
            throw AuthCodeStorageError.KEY_ERROR
        }

        // Log Task and EventLoop information
        Log.info("DEBUG REDIS: PUSH START - loginid: \(session.loginId.uuidString)")
        Log.info("DEBUG REDIS: PUSH Task: \(Task.currentPriority)")
        Log.info("DEBUG REDIS: PUSH EventLoop: \(redis.eventLoop)")

        let sessionData = try JSONEncoder.main.encode(session)
        let stringValue = String(data: sessionData, encoding: .utf8)
        let valueLength = stringValue?.count ?? 0
        Log.info("DEBUG REDIS: About to call redis.set() for key: \(key.rawValue), value length: \(valueLength)")

        // Execute SET and wait for completion
        let setStartTime = Date()
        try await redis.set(key, to: stringValue).get()
        let setDuration = Date().timeIntervalSince(setStartTime) * 1000
        Log.info("DEBUG REDIS: redis.set() completed in \(setDuration)ms")

        // Execute EXPIRE and wait for completion
        let expireStartTime = Date()
        _ = try await redis.expire(key, after: TimeAmount.seconds(60 * 120)).get()
        let expireDuration = Date().timeIntervalSince(expireStartTime) * 1000
        Log.info("DEBUG REDIS: redis.expire() completed in \(expireDuration)ms")

        // IMMEDIATE VERIFICATION - Same connection
        if let verifyValue = try? await redis.get(key).get() {
            let verifyLength = verifyValue.string?.count ?? 0
            Log.info("DEBUG REDIS: IMMEDIATE VERIFICATION SUCCESSFUL - Key exists, value length: \(verifyLength)")
        } else {
            Log.error("DEBUG REDIS: IMMEDIATE VERIFICATION FAILED - Key NOT found!")
        }

        // WAIT 50ms and verify again
        try? await Task.sleep(nanoseconds: 50_000_000)
        if let verifyValue = try? await redis.get(key).get() {
            let verifyLength = verifyValue.string?.count ?? 0
            Log.info("DEBUG REDIS: VERIFICATION AFTER 50ms SUCCESSFUL - Key exists, value length: \(verifyLength)")
        } else {
            Log.error("DEBUG REDIS: VERIFICATION AFTER 50ms FAILED - Key NOT found!")
        }

        // WAIT 100ms more (150ms total) and verify again
        try? await Task.sleep(nanoseconds: 100_000_000)
        if let verifyValue = try? await redis.get(key).get() {
            let verifyLength = verifyValue.string?.count ?? 0
            Log.info("DEBUG REDIS: VERIFICATION AFTER 150ms SUCCESSFUL - Key exists, value length: \(verifyLength)")
        } else {
            Log.error("DEBUG REDIS: VERIFICATION AFTER 150ms FAILED - Key NOT found!")
        }

        Log.info("DEBUG REDIS: PUSH END - loginid: \(session.loginId.uuidString)")
    }

    func pull(loginUuid uuid: UUID) async -> Bool {
        Log.info("DEBUG REDIS: PULL START - loginid: \(uuid.uuidString)")
        Log.info("DEBUG REDIS: PULL Task: \(Task.currentPriority)")
        Log.info("DEBUG REDIS: PULL EventLoop: \(redis.eventLoop)")

        guard let key = RedisKey(rawValue: "loginid~" + uuid.uuidString) else {
            Log.error("DEBUG REDIS: Failed to create RedisKey for pull: \(uuid.uuidString)")
            return false
        }

        Log.info("DEBUG REDIS: About to call redis.get() for key: \(key.rawValue)")

        let getStartTime = Date()
        guard let value = try? await redis.get(key).get() else {
            let getDuration = Date().timeIntervalSince(getStartTime) * 1000
            Log.error("DEBUG REDIS: PULL FAILED in \(getDuration)ms - Key '\(key.rawValue)' NOT FOUND in Redis!")

            // Try to list all keys to see what's actually in Redis
            do {
                let (_, keys) = try await redis.scan(startingFrom: 0).get()
                Log.error("DEBUG REDIS: Current keys in Redis: \(keys.joined(separator: ", "))")
                let loginKeys = keys.filter { $0.contains("loginid~") }
                Log.error("DEBUG REDIS: Login keys in Redis: \(loginKeys.joined(separator: ", "))")
            } catch {
                Log.error("DEBUG REDIS: Failed to scan Redis keys: \(error)")
            }

            // WAIT 100ms and try again to see if it's a timing issue
            Log.info("DEBUG REDIS: RETRY - Waiting 100ms and trying again...")
            try? await Task.sleep(nanoseconds: 100_000_000)

            if let retryValue = try? await redis.get(key).get() {
                let retryLength = retryValue.string?.count ?? 0
                Log.info("DEBUG REDIS: RETRY SUCCESS - Key found after 100ms wait! Value length: \(retryLength)")
                // Continue with this value instead of returning false
                return await processValue(retryValue, uuid: uuid, key: key)
            } else {
                Log.error("DEBUG REDIS: RETRY FAILED - Key still not found after 100ms wait")
                return false
            }
        }

        let getDuration = Date().timeIntervalSince(getStartTime) * 1000
        Log.info("DEBUG REDIS: redis.get() found value in \(getDuration)ms, length: \(value.string?.count ?? 0)")

        return await processValue(value, uuid: uuid, key: key)
    }

    private func processValue(_ value: RESPValue, uuid: UUID, key: RedisKey) async -> Bool {
        _ = try? await redis.delete([key]).get()
        Log.info("DEBUG REDIS: Key deleted from Redis")

        guard let data = value.data else {
            Log.error("DEBUG REDIS: No data in Redis value for loginid: \(uuid.uuidString)")
            return false
        }

        if let sessionData = try? JSONDecoder.main.decode(LoginSession.self, from: data) {
            let matches = sessionData.loginId == uuid
            Log.info("DEBUG REDIS: PULL SUCCESS - loginid: \(uuid.uuidString), matches: \(matches)")
            return matches
        }

        Log.error("DEBUG REDIS: Failed to decode LoginSession for loginid: \(uuid.uuidString)")
        return false
    }

    func delete(type: AuthSession.CodeType, codeValue value: String) async throws {
        guard let key = RedisKey(rawValue: "\(type)~" + value) else {
            return
        }
        _ = try await redis.delete(key).get()
    }

    func wipe(tenant: Tenant, subject: String) async {
        // No longer needs DispatchQueue since we're in an actor context
        do {
            let (_, keys) = try await redis.scan(startingFrom: 0).get()
            Log.debug("Checking \(keys.count) tokens for retention")
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
            Log.debug("Deleting \(keysToDelete.count) tokens")
            if !keysToDelete.isEmpty {
                _ = try await redis.delete(keysToDelete).get()
            }
        } catch {
            Log.error("Cannot get all redis keys. \(error)")
        }
    }

    func isHealthy() async -> Bool {
        if (try? await redis.ping().get()) == "PONG" {
            Log.debug("Redis is healthy")
            return true
        }

        Log.error("Redis is not healthy")
        return false
    }
}
