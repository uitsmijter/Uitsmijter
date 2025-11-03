import Foundation
import CoreFoundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer
@MainActor
@Suite struct AuthCodeMemoryStorageGarbageCollectionTest {

    @Test func storeSessionsInMemoryGarbageCollection() async throws {
        let storage = MemoryAuthCodeStorage()

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
            try await storage.set(authSession: session_1)
            try await storage.set(authSession: session_2)
            try await storage.set(authSession: session_3)
        } catch {
            Issue.record("Can not set authSession in storage")
            return
        }

        #expect(await storage.count() == 3)

        // Wait for session 1 to expire
        try? await Task.sleep(for: .seconds(2.1))
        let ret_nil_1 = await storage.get(type: .code, codeValue: "code_1")
        #expect(ret_nil_1 == nil)

        // Wait for session 2 to expire (additional 2 seconds from session 1)
        try? await Task.sleep(for: .seconds(2.0))
        let ret_nil_2 = await storage.get(type: .code, codeValue: "code_2")
        #expect(ret_nil_2 == nil)

        // Wait for session 3 to expire (additional 2 seconds from session 2)
        try? await Task.sleep(for: .seconds(2.0))
        let ret_nil_3 = await storage.get(type: .code, codeValue: "code_3")
        #expect(ret_nil_3 == nil)

        // all gone?
        // swiftlint:disable:next empty_count
        #expect(await storage.count() == 0)
    }

}
