import Foundation
@preconcurrency import Redis
import Logger

/// Actor-based thread-safe Redis storage for authorization codes and login sessions
actor RedisAuthCodeStorage: AuthCodeStorageProtocol {
    /// TTL for login session IDs in seconds (2 hours)
    private static let loginSessionTTL: Int64 = 60 * 120

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
        _ = try await redis.expire(key, after: TimeAmount.seconds(Self.loginSessionTTL)).get()
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
        Log.debug("Wipe AuthSession for tenant: \(tenant.name) with subject: \(subject)")
        do {
            let (_, keys) = try await redis.scan(startingFrom: 0).get()
            let keysToDelete: [RedisKey] = try await withThrowingTaskGroup(of: RedisKey?.self) { group in
                for key in keys {
                    group.addTask {
                        // Skip non-AuthSession keys (loginid~ keys are LoginSession, not AuthSession)
                        if key.hasPrefix("loginid~") {
                            return nil
                        }

                        if let rKey = RedisKey(rawValue: key) {
                            let value = try? await self.redis.get(rKey).get()
                            if let data = value?.data {
                                let decoded = try JSONDecoder.main.decode(AuthSession.self, from: data)
                                if decoded.payload?.tenant == tenant.name && decoded.payload?.subject.value == subject {
                                    Log.debug(
                                        """
                                        Matching session found in Redis - Type: \(decoded.type.rawValue), \
                                        Tenant: \(decoded.payload?.tenant ?? "nil"), \
                                        Subject: \(decoded.payload?.subject.value ?? "nil"), \
                                        Key: \(key)
                                        """
                                    )
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
            Log.debug("Found \(keysToDelete.count) sessions to wipe from Redis")
            if !keysToDelete.isEmpty {
                _ = try await redis.delete(keysToDelete).get()
                Log.debug("Successfully deleted \(keysToDelete.count) sessions from Redis")
            }
        } catch {
            Log.error("Cannot get all redis keys. \(error)")
        }
    }

    func count(tenant: Tenant, type: AuthSession.CodeType) async -> Int {
        Log.debug("Count AuthSession for tenant: \(tenant.name) with type: \(type.rawValue)")
        do {
            let (_, keys) = try await redis.scan(startingFrom: 0).get()
            let matchingKeys: Int = try await withThrowingTaskGroup(of: Int.self) { group in
                for key in keys {
                    group.addTask {
                        // Skip non-AuthSession keys (loginid~ keys are LoginSession, not AuthSession)
                        if key.hasPrefix("loginid~") {
                            return 0
                        }

                        if let rKey = RedisKey(rawValue: key) {
                            let value = try? await self.redis.get(rKey).get()
                            if let data = value?.data {
                                // Try to decode as AuthSession, but skip if it's a different type
                                // (e.g., LoginSession which doesn't have a 'type' field)
                                if let decoded = try? JSONDecoder.main.decode(AuthSession.self, from: data) {
                                    if decoded.payload?.tenant == tenant.name && decoded.type == type {
                                        Log.debug(
                                            """
                                            Session in count - Type: \(decoded.type.rawValue), \
                                            Tenant: \(decoded.payload?.tenant ?? "nil"), \
                                            Subject: \(decoded.payload?.subject.value ?? "nil"), \
                                            Key: \(key)
                                            """
                                        )
                                        return 1
                                    }
                                }
                            }
                        }
                        return 0
                    }
                }

                var total = 0
                for try await count in group {
                    total += count
                }
                return total
            }
            Log.debug("Total matching sessions: \(matchingKeys)")
            return matchingKeys
        } catch {
            Log.error("Cannot count redis keys for tenant: \(error)")
            return 0
        }
    }

    func count(client: UitsmijterClient, type: AuthSession.CodeType) async -> Int {
        Log.debug("Count AuthSession for client: \(client.name) with type: \(type.rawValue)")
        do {
            let (_, keys) = try await redis.scan(startingFrom: 0).get()
            let matchingKeys: Int = try await withThrowingTaskGroup(of: Int.self) { group in
                for key in keys {
                    group.addTask {
                        // Skip non-AuthSession keys (loginid~ keys are LoginSession, not AuthSession)
                        if key.hasPrefix("loginid~") {
                            return 0
                        }

                        if let rKey = RedisKey(rawValue: key) {
                            let value = try? await self.redis.get(rKey).get()
                            if let data = value?.data {
                                // Try to decode as AuthSession, but skip if it's a different type
                                if let decoded = try? JSONDecoder.main.decode(AuthSession.self, from: data) {
                                    // Match by audience (client_id) in the payload and type
                                    guard let payload = decoded.payload else { return 0 }
                                    let audienceMatches = payload.audience.value.contains(client.name)
                                    if audienceMatches && decoded.type == type {
                                        Log.debug(
                                            """
                                            Session in count - Type: \(decoded.type.rawValue), \
                                            Client: \(payload.audience.value.joined(separator: ",")), \
                                            Subject: \(payload.subject.value), \
                                            Key: \(key)
                                            """
                                        )
                                        return 1
                                    }
                                }
                            }
                        }
                        return 0
                    }
                }

                var total = 0
                for try await count in group {
                    total += count
                }
                return total
            }
            Log.debug("Total matching sessions for client: \(matchingKeys)")
            return matchingKeys
        } catch {
            Log.error("Cannot count redis keys for client: \(error)")
            return 0
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
