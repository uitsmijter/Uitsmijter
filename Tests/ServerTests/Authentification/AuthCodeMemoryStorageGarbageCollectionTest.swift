import Foundation
import CoreFoundation
import XCTVapor
@testable import Server

final class AuthCodeMemoryStorageGarbageCollectionTest: XCTestCase {
    let storage = MemoryAuthCodeStorage()

    override func setUp() {
        let session_1 = AuthSession(
                type: .code,
                state: "state_1",
                code: Code(value: "code_1"),
                scopes: [],
                payload: nil,
                redirect: "", ttl: 2
        )
        let session_2 = AuthSession(
                type: .code,
                state: "state_2",
                code: Code(value: "code_2"),
                scopes: [],
                payload: nil,
                redirect: "", ttl: 4
        )
        let session_3 = AuthSession(
                type: .code,
                state: "state_3",
                code: Code(value: "code_3"),
                scopes: [],
                payload: nil,
                redirect: "",
                ttl: 6
        )
        do {
            try storage.set(authSession: session_1)
            try storage.set(authSession: session_2)
            try storage.set(authSession: session_3)
        } catch {
            XCTFail("Can not set authSession in storage")
        }
    }

    func testStoreSessionsInMemoryGarbageCollection() async throws {
        let expectation_1 = expectation(description: "Wait for end of  ttl")
        let expectation_2 = expectation(description: "Wait for end of  ttl")
        let expectation_3 = expectation(description: "Wait for end of ttl")

        XCTAssertEqual(storage.count, 3)
        _ = Timer.scheduledTimer(withTimeInterval: 2.1, repeats: false) { _ in
            let ret_nil = self.storage.get(type: .code, codeValue: "code_1")
            XCTAssertNil(ret_nil)
            expectation_1.fulfill()
        }
        _ = Timer.scheduledTimer(withTimeInterval: 4.1, repeats: false) { _ in
            let ret_nil = self.storage.get(type: .code, codeValue: "code_2")
            XCTAssertNil(ret_nil)
            expectation_2.fulfill()
        }
        _ = Timer.scheduledTimer(withTimeInterval: 6.1, repeats: false) { _ in
            let ret_nil = self.storage.get(type: .code, codeValue: "code_3")
            XCTAssertNil(ret_nil)
            expectation_3.fulfill()
        }

        wait(for: [expectation_1, expectation_2, expectation_3], timeout: 10)

        // all gone?
        XCTAssertEqual(storage.count, 0)
    }

}
