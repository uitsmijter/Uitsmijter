import Foundation
import Vapor
@preconcurrency import Redis
import Logger

/// Concrete implementation of AuthCodeStorage that delegates to different storage backends
struct AuthCodeStorage: AuthCodeStorageProtocol, Sendable {

    private let implementation: AuthCodeStorageProtocol

    init(use: AuthCodeStorageImplementations) {
        switch use {
        case .redis(let client):
            implementation = RedisAuthCodeStorage(client)
        case .memory:
            implementation = MemoryAuthCodeStorage()
        case .custom(implementation: let customImplementation):
            implementation = customImplementation
        }
    }

    // MARK: - AuthCodeStorageProtocol

    func set(authSession session: AuthSession) async throws {
        try await implementation.set(authSession: session)
        let thread = Thread { [self] in
            Log.debug("Counting keys in AuthStorage...")
            Task {
                let countKeysInStorage = await count()
                Log.debug("Found \(countKeysInStorage) keys in AuthStorage")
                metricsTokensStored?.observe(countKeysInStorage)
            }
        }
        thread.main()
    }

    func get(
        type codeType: AuthSession.CodeType,
        codeValue value: String,
        remove: Bool? = false
    ) async -> AuthSession? {
        Log.debug("Get AuthSession for type \(codeType.rawValue) with value \(value)")
        return await implementation.get(type: codeType, codeValue: value, remove: remove)
    }

    func push(loginId session: LoginSession) async throws {
        Log.debug("Push AuthSession loginId: \(session.loginId.uuidString)")
        try await implementation.push(loginId: session)
    }

    func pull(loginUuid uuid: UUID) async -> Bool {
        Log.debug("Pull AuthSession loginUuid: \(uuid.uuidString)")
        return await implementation.pull(loginUuid: uuid)
    }

    func count() async -> Int {
        Log.debug("Count AuthSession")
        return await implementation.count()
    }

    func delete(type codeType: AuthSession.CodeType, codeValue value: String) async throws {
        Log.debug("Delete AuthSession for type \(codeType.rawValue) with value: \(value)")
        try await implementation.delete(type: codeType, codeValue: value)
    }

    func wipe(tenant: Tenant, subject: String) async {
        Log.debug("Wipe AuthSession for tenant: \(tenant.name) with subject: \(subject)")
        await implementation.wipe(tenant: tenant, subject: subject)
    }

    func isHealthy() async -> Bool {
        await implementation.isHealthy()
    }
}

/// Storage key for Vapor's Application storage
struct AuthCodeStorageKey: StorageKey {
    typealias Value = AuthCodeStorage
}

/// Extension to add authCodeStorage to Vapor's Application
extension Application {
    var authCodeStorage: AuthCodeStorage? {
        get {
            storage[AuthCodeStorageKey.self]
        }
        set {
            storage[AuthCodeStorageKey.self] = newValue
        }
    }
}
