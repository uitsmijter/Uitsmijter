import Foundation
import CoreFoundation
import Dispatch
import Logger

/// Actor-based thread-safe storage for authorization codes and login sessions
actor MemoryAuthCodeStorage: AuthCodeStorageProtocol {
    /// Poor mans GarbageCollector, trigger timer (using DispatchSourceTimer for Docker compatibility)
    private var gcTimer: DispatchSourceTimer?

    /// Storage for AuthSessions
    private var storage: [AuthSession] = []

    /// Storage for LoginSessions
    private var loginSessions: [LoginSession] = []

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

    /// Stores an authorization session in memory.
    ///
    /// - Parameter session: The authorization session to store
    /// - Throws: `AuthCodeStorageError.CODE_TAKEN` if a session with this code already exists
    func set(authSession session: AuthSession) async throws {
        if storage.contains(where: { $0.code.value == session.code.value }) {
            throw AuthCodeStorageError.CODE_TAKEN
        }
        Log.debug(
            """
            Storing new session - Type: \(session.type.rawValue), \
            Tenant: \(session.payload?.tenant ?? "nil"), \
            Subject: \(session.payload?.subject.value ?? "nil"), \
            TTL: \(String(describing: session.ttl))
            """
        )
        storage.append(session)
        sortAndGc()
        Log.debug("Total sessions in storage after set: \(storage.count)")
    }

    /// Retrieves an authorization session by code value.
    ///
    /// - Parameters:
    ///   - type: The type of authorization code (code or refresh)
    ///   - value: The authorization code value to look up
    ///   - remove: If true, removes the session after retrieval (single-use enforcement)
    /// - Returns: The authorization session if found, nil otherwise
    func get(type: AuthSession.CodeType, codeValue value: String, remove: Bool? = false) async -> AuthSession? {
        let session = storage.first(where: { $0.code.value == value && $0.type == type })
        if remove ?? false {
            storage.removeAll(where: { $0.code.value == value && $0.type == type })
        }
        return session
    }

    /// Stores a login session in memory.
    ///
    /// - Parameter session: The login session to store
    /// - Throws: Can throw errors from storage operations
    func push(loginId session: LoginSession) async throws {
        loginSessions.append(session)
    }

    /// Retrieves and removes a login session by UUID.
    ///
    /// - Parameter uuid: The login session UUID to look up
    /// - Returns: true if the session was found and removed, false otherwise
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

    /// Returns the number of stored authorization sessions.
    ///
    /// - Returns: The count of authorization sessions in storage
    func count() async -> Int {
        return storage.count
    }

    /// Deletes an authorization session by code value.
    ///
    /// - Parameters:
    ///   - type: The type of authorization code (code or refresh)
    ///   - value: The authorization code value to delete
    /// - Throws: Can throw errors from storage operations
    func delete(type: AuthSession.CodeType, codeValue value: String) async throws {
        storage.removeAll(where: { $0.code.value == value && $0.type == type })
    }

    /// Removes all authorization sessions for a specific user.
    ///
    /// - Parameters:
    ///   - tenant: The tenant containing the user
    ///   - subject: The subject (user identifier) whose sessions should be removed
    func wipe(tenant: Tenant, subject: String) async {
        Log.debug("Wipe called for tenant: \(tenant.name), subject: \(subject)")
        Log.debug("Total sessions in storage before wipe: \(storage.count)")

        // Log all sessions that match the criteria before removing
        let matchingSessions = storage.filter { session in
            let matches = session.payload?.tenant == tenant.name && session.payload?.subject.value == subject
            if matches {
                Log.debug(
                    """
                    Matching session found - Type: \(session.type.rawValue), \
                    Tenant: \(session.payload?.tenant ?? "nil"), \
                    Subject: \(session.payload?.subject.value ?? "nil")
                    """
                )
            }
            return matches
        }
        Log.debug("Found \(matchingSessions.count) sessions to wipe")

        storage.removeAll(where: { $0.payload?.tenant == tenant.name && $0.payload?.subject.value == subject })
        Log.debug("Total sessions in storage after wipe: \(storage.count)")
    }

    /// Counts authorization sessions for a specific tenant and type.
    ///
    /// - Parameters:
    ///   - tenant: The tenant to count sessions for
    ///   - type: The type of sessions to count (e.g., .refresh for long-lived sessions)
    /// - Returns: The number of sessions matching the criteria
    func count(tenant: Tenant, type: AuthSession.CodeType) async -> Int {
        let matchingSessions = storage.filter { $0.payload?.tenant == tenant.name && $0.type == type }
        Log.debug("Count called for tenant: \(tenant.name), type: \(type.rawValue) - found \(matchingSessions.count)")

        // Log details of each matching session for debugging
        for session in matchingSessions {
            Log.debug(
                """
                Session in count - Type: \(session.type.rawValue), \
                Tenant: \(session.payload?.tenant ?? "nil"), \
                Subject: \(session.payload?.subject.value ?? "nil")
                """
            )
        }

        return matchingSessions.count
    }

    /// Checks if the storage backend is healthy and operational.
    ///
    /// - Returns: Always returns true for memory storage (always available)
    func isHealthy() async -> Bool {
        true
    }
}
