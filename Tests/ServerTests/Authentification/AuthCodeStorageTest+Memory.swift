import Foundation
import XCTVapor
@testable import Server

final class AuthCodeStorageMemoryTest: XCTestCase {
    let storage = AuthCodeStorage(use: .memory)

    override func setUp() {
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
            try storage.set(authSession: session_1)
            try storage.set(authSession: session_2)
            try storage.set(authSession: session_TTL)
        } catch {
            XCTFail("Error: \(error.localizedDescription)")
        }
    }

    func testStoreSessionsInMemoryNil() async throws {
        let ret_nil = storage.get(type: .code, codeValue: "code_0")
        XCTAssertNil(ret_nil)
    }

    func testStoreSessionsInMemoryGetNotRemovedDefault() async throws {
        let ret_set = storage.get(type: .code, codeValue: "code_1")
        XCTAssertNotNil(ret_set)
        let ret_set_twice = storage.get(type: .code, codeValue: "code_1")
        XCTAssertNotNil(ret_set_twice)

        XCTAssertEqual(ret_set?.state, "state_1")
        XCTAssertEqual(ret_set?.code.value, "code_1")
    }

    func testStoreSessionsInMemoryGetRemoved() async throws {
        let ret_set = storage.get(type: .code, codeValue: "code_1", remove: true)
        XCTAssertNotNil(ret_set)
        let ret_set_twice = storage.get(type: .code, codeValue: "code_1")
        XCTAssertNil(ret_set_twice)

        XCTAssertEqual(ret_set?.state, "state_1")
        XCTAssertEqual(ret_set?.code.value, "code_1")
    }

    func testStoreSessionsInMemoryTTL() async throws {
        sleep(2)
        let ret_set = storage.get(type: .code, codeValue: "code_TTL")
        XCTAssertNil(ret_set)
    }

    // MARK: - LoginId

    func testStoreLoginId() async throws {
        let loginId = UUID()
        let session = LoginSession(loginId: loginId)
        try storage.push(loginId: session)

        // not in store
        XCTAssertFalse(storage.pull(loginUuid: UUID()))

        // in store
        XCTAssertTrue(storage.pull(loginUuid: loginId))

        // is deleted
        XCTAssertFalse(storage.pull(loginUuid: loginId))
    }
}
