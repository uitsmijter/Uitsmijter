import Foundation
import CoreFoundation
import Dispatch
import Logger

/// Actor-based thread-safe storage for authorization codes and login sessions
/// Converted from @unchecked Sendable to proper Actor isolation per ACTOR.md recommendations
actor MemoryAuthCodeStorage: AuthCodeStorageProtocol {
    /// Poor mans GarbageCollector, trigger timer (using DispatchSourceTimer for Docker compatibility)
    private var gcTimer: DispatchSourceTimer?

    /// Storage for AuthSessions
    private var storage: [AuthSession] = []

    /// Storage for LoginSessions - no longer needs @Synchronised wrapper due to actor isolation
    private var loginSessions: [LoginSession] = []

    var count: Int {
        get {
            storage.count
        }
    }

    /// Sort storage and restart garbage collection
    private func sortAndGc() {
        gcTimer?.cancel()
        gcTimer = nil
        storage.sort { (key, value) in
            key.generated.addingTimeInterval(TimeInterval(key.ttl ?? 0))
                > value.generated.addingTimeInterval(TimeInterval(value.ttl ?? 0))
        }
        gc()
    }

    /// Poor mans GarbageCollector, gc
    /// Uses DispatchSourceTimer instead of Foundation.Timer for Docker/container compatibility
    /// Foundation.Timer requires an active RunLoop, which may not be available in test environments
    private func gc() {
        guard let lastElement = storage.last else {
            return
        }
        if let ttl = lastElement.ttl {
            let interval = lastElement.generated.addingTimeInterval(TimeInterval(ttl)).timeIntervalSinceNow

            // Ensure interval is positive
            guard interval > 0 else {
                // Already expired, remove immediately
                if storage.isEmpty == false {
                    let removed = storage.removeLast()
                    Log.debug("Removing code: \(removed.code.value), TTL: \(String(describing: removed.ttl))")
                    gc()
                }
                return
            }

            // Create new DispatchSourceTimer
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + interval)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                Task {
                    await self.removeExpired()
                }
            }
            timer.resume()
            gcTimer = timer
        }
    }

    /// Remove expired entry and trigger next GC
    private func removeExpired() {
        if storage.isEmpty == false {
            let removed = storage.removeLast()
            Log.debug("Removing code: \(removed.code.value), TTL: \(String(describing: removed.ttl))")
            gc()
        }
    }

    // MARK: - AuthCodeStorageProtocol

    func set(authSession session: AuthSession) async throws {
        if storage.contains(where: { $0.code.value == session.code.value }) {
            throw AuthCodeStorageError.CODE_TAKEN
        }
        storage.append(session)
        sortAndGc()
    }

    func get(type: AuthSession.CodeType, codeValue value: String, remove: Bool? = false) async -> AuthSession? {
        let session = storage.first(where: { $0.code.value == value && $0.type == type })
        if remove ?? false {
            storage.removeAll(where: { $0.code.value == value && $0.type == type })
        }
        return session
    }

    func push(loginId session: LoginSession) async throws {
        loginSessions.append(session)
    }

    func pull(loginUuid uuid: UUID) async -> Bool {
        let session = loginSessions.first { session in
            session.loginId == uuid
        }
        if session == nil {
            return false
        }
        loginSessions = loginSessions.filter { session in
            session.loginId != uuid
        }
        return true
    }

    func count() async -> Int {
        return storage.count
    }

    func delete(type: AuthSession.CodeType, codeValue value: String) async throws {
        storage.removeAll(where: { $0.code.value == value && $0.type == type })
    }

    func wipe(tenant: Tenant, subject: String) async {
        storage.removeAll(where: { $0.payload?.tenant == tenant.name && $0.payload?.subject.value == subject })
    }

    func isHealthy() async -> Bool {
        true
    }
}
