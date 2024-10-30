import Foundation
import Vapor
import Redis

protocol AuthCodeStorageProtocol {
    func set(authSession: AuthSession) throws
    func get(type: AuthSession.CodeType, codeValue: String, remove: Bool?) -> AuthSession?

    func push(loginId: LoginSession) throws
    func pull(loginUuid: UUID) -> Bool

    func count(completion: @escaping (Int) -> Void)
    func delete(type: AuthSession.CodeType, codeValue: String) throws
    func wipe(tenant: Tenant, subject: String)
    func isHealthy() -> Bool
}

enum AuthCodeStorageError: Error {
    case CODE_TAKEN
    case KEY_ERROR
}

struct AuthCodeStorage: AuthCodeStorageProtocol {

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

    func set(authSession session: AuthSession) throws {
        try implementation.set(authSession: session)
        let thread = Thread { [self] in
            Log.info("Count keys in AuthStorage...")
            count { countKeysInStorage in
                Log.info("Found \(countKeysInStorage) keys in AuthStorage")
                metricsTokensStored?.observe(countKeysInStorage)
            }
        }
        thread.main()
    }

    func get(type codeType: AuthSession.CodeType, codeValue value: String, remove: Bool? = false) -> AuthSession? {
        Log.debug("Get AuthSession for type \(codeType.rawValue) with value \(value)")
        return implementation.get(type: codeType, codeValue: value, remove: remove)
    }

    func push(loginId session: LoginSession) throws {
        Log.debug("Push AuthSession loginId: \(session.loginId.uuidString)")
        try implementation.push(loginId: session)
    }

    func pull(loginUuid uuid: UUID) -> Bool {
        Log.debug("Pull AuthSession loginUuid: \(uuid.uuidString)")
        return implementation.pull(loginUuid: uuid)
    }

    func count(completion: @escaping (Int) -> Void) {
        Log.debug("Count AuthSession")
        implementation.count(completion: completion)
    }

    func delete(type codeType: AuthSession.CodeType, codeValue value: String) throws {
        Log.debug("Delete AuthSession for type \(codeType.rawValue) with value: \(value)")
        try implementation.delete(type: codeType, codeValue: value)
    }

    func wipe(tenant: Tenant, subject: String) {
        Log.debug("Wipe AuthSession for tenant: \(tenant.name) with subject: \(subject)")
        implementation.wipe(tenant: tenant, subject: subject)
    }

    func isHealthy() -> Bool {
        implementation.isHealthy()
    }
}

struct AuthCodeStorageKey: StorageKey {
    typealias Value = AuthCodeStorage
}

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
