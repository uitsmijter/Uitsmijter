import Foundation
import CoreFoundation

class MemoryAuthCodeStorage: AuthCodeStorageProtocol {
    /// Poor mans GarbageCollector, trigger timer
    var gcTimer: Timer?

    /// Storage for AuthSessions
    var storage: [AuthSession] = [] {
        didSet {
            gcTimer?.invalidate()
            storage.sort { (key, value) in
                key.generated.addingTimeInterval(TimeInterval(key.ttl ?? 0))
                        > value.generated.addingTimeInterval(TimeInterval(value.ttl ?? 0))
            }
            gc()
        }
    }

    @Synchronised var loginSessions: [LoginSession] = []

    var count: Int {
        get {
            storage.count
        }
    }

    /// Poor mans GarbageCollector, gc
    private func gc() {
        guard let lastElement = storage.last else {
            return
        }
        if let ttl = lastElement.ttl {
            let interval = lastElement.generated.addingTimeInterval(TimeInterval(ttl)).timeIntervalSinceNow
            gcTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [self] timer in
                timer.invalidate()
                if storage.isEmpty == false {
                    let removed = storage.removeLast()
                    Log.info("Remove Code: \(removed.code.value), TTL: \(String(describing: removed.ttl))")
                    gc()
                }
            }
        }
    }

    // MARK: - AuthCodeStorageProtocol

    func set(authSession session: AuthSession) throws {
        if storage.contains(where: { $0.code.value == session.code.value }) {
            throw AuthCodeStorageError.CODE_TAKEN
        }
        storage.append(session)
    }

    func get(type: AuthSession.CodeType, codeValue value: String, remove: Bool? = false) -> AuthSession? {
        let session = storage.first(where: { $0.code.value == value && $0.type == type })
        if remove ?? false {
            storage.removeAll(where: { $0.code.value == value && $0.type == type })
        }
        return session
    }

    func push(loginId session: LoginSession) throws {
        loginSessions.append(session)
    }

    func pull(loginUuid uuid: UUID) -> Bool {
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

    func count(completion: @escaping (Int) -> Void) {
        completion(storage.count)
    }

    func delete(type: AuthSession.CodeType, codeValue value: String) throws {
        storage.removeAll(where: { $0.code.value == value && $0.type == type })
    }

    func wipe(tenant: Tenant, subject: String) {
        storage.removeAll(where: { $0.payload?.tenant == tenant.name && $0.payload?.subject.value == subject })
    }

    func isHealthy() -> Bool {
        true
    }
}
