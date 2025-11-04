import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer
@MainActor
@Suite struct AuthCodeStorageMemoryTest {

    func setupStorage() async throws -> AuthCodeStorage {
        let storage = AuthCodeStorage(use: .memory)

        let session_1 = AuthSession(
            type: .code,
            state: "state_1",
            code: Code(value: "code_1"),
            scopes: ["foo", "bar"],
            payload: nil,
            redirect: "",
            ttl: 10
        )
        let session_2 = AuthSession(
            type: .code,
            state: "state_2",
            code: Code(value: "code_2"),
            scopes: ["foo", "bar"],
            payload: nil,
            redirect: "",
            ttl: 50
        )
        let session_TTL = AuthSession(
            type: .code,
            state: "state_TTL",
            code: Code(value: "code_TTL"),
            scopes: [],
            payload: nil,
            redirect: "",
            ttl: 1
        )
        do {
            try await storage.set(authSession: session_1)
            try await storage.set(authSession: session_2)
            try await storage.set(authSession: session_TTL)
        } catch {
            Issue.record("Error: \(error.localizedDescription)")
        }

        return storage
    }

    @Test func storeSessionsInMemoryNil() async throws {
        let storage = try await setupStorage()

        let ret_nil = await storage.get(type: .code, codeValue: "code_0")
        #expect(ret_nil == nil)
    }

    @Test func storeSessionsInMemoryGetNotRemovedDefault() async throws {
        let storage = try await setupStorage()

        let ret_set = await storage.get(type: .code, codeValue: "code_1")
        #expect(ret_set != nil)
        let ret_set_twice = await storage.get(type: .code, codeValue: "code_1")
        #expect(ret_set_twice != nil)

        #expect(ret_set?.state == "state_1")
        #expect(ret_set?.code.value == "code_1")
    }

    @Test func storeSessionsInMemoryGetRemoved() async throws {
        let storage = try await setupStorage()

        let ret_set = await storage.get(type: .code, codeValue: "code_1", remove: true)
        #expect(ret_set != nil)
        let ret_set_twice = await storage.get(type: .code, codeValue: "code_1")
        #expect(ret_set_twice == nil)

        #expect(ret_set?.state == "state_1")
        #expect(ret_set?.code.value == "code_1")
    }

    @Test func storeSessionsInMemoryTTL() async throws {
        let storage = try await setupStorage()

        try await Task.sleep(for: .seconds(2))
        let ret_set = await storage.get(type: .code, codeValue: "code_TTL")
        #expect(ret_set == nil)
    }

    // MARK: - LoginId

    @Test func storeLoginId() async throws {
        let storage = AuthCodeStorage(use: .memory)

        let loginId = UUID()
        let session = LoginSession(loginId: loginId)
        try await storage.push(loginId: session)

        // not in store
        #expect(await storage.pull(loginUuid: UUID()) == false)

        // in store
        #expect(await storage.pull(loginUuid: loginId) == true)

        // is deleted
        #expect(await storage.pull(loginUuid: loginId) == false)
    }
}
