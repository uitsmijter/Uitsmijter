import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("Device Storage Tests")
struct DeviceStorageTests {

    private func makeDeviceSession(
        clientId: String = "test-client-001",
        deviceCode: String = "dev-code-0001",
        userCode: String = "ABCD-EFGH",
        status: DeviceGrantStatus = .pending
    ) -> AuthSession {
        AuthSession.device(DeviceSession(
            clientId: clientId,
            deviceCode: Code(value: deviceCode),
            userCode: userCode,
            scopes: ["read"],
            payload: nil,
            status: status
        ))
    }

    // MARK: - getDevice(byUserCode:)

    @Test("getDevice returns session for known user code")
    func getDeviceByKnownUserCode() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        let found = await storage.getDevice(byUserCode: "ABCD-EFGH")
        #expect(found != nil)
        #expect(found?.codeValue == "dev-code-0001")
    }

    @Test("getDevice returns nil for unknown user code")
    func getDeviceByUnknownUserCode() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        let notFound = await storage.getDevice(byUserCode: "ZZZZ-ZZZZ")
        #expect(notFound == nil)
    }

    @Test("getDevice is case-sensitive for user code")
    func getDeviceCaseSensitiveUserCode() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession(userCode: "ABCD-EFGH"))

        let notFound = await storage.getDevice(byUserCode: "abcd-efgh")
        #expect(notFound == nil)
    }

    // MARK: - updateDevice

    @Test("updateDevice changes status to authorized")
    func updateDeviceToAuthorized() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        try await storage.updateDevice(
            deviceCode: "dev-code-0001",
            newStatus: .authorized,
            payload: nil,
            lastPolledAt: nil
        )

        let updated = await storage.get(type: .device, codeValue: "dev-code-0001")
        guard case .device(let data) = updated else {
            Issue.record("Expected device session after update")
            return
        }
        #expect(data.status == .authorized)
    }

    @Test("updateDevice changes status to denied")
    func updateDeviceToDenied() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        try await storage.updateDevice(
            deviceCode: "dev-code-0001",
            newStatus: .denied,
            payload: nil,
            lastPolledAt: nil
        )

        let updated = await storage.get(type: .device, codeValue: "dev-code-0001")
        guard case .device(let data) = updated else {
            Issue.record("Expected device session after update")
            return
        }
        #expect(data.status == .denied)
    }

    @Test("updateDevice records lastPolledAt")
    func updateDeviceRecordsLastPolledAt() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        let pollTime = Date()
        try await storage.updateDevice(
            deviceCode: "dev-code-0001",
            newStatus: .pending,
            payload: nil,
            lastPolledAt: pollTime
        )

        let updated = await storage.get(type: .device, codeValue: "dev-code-0001")
        guard case .device(let data) = updated else {
            Issue.record("Expected device session after update")
            return
        }
        #expect(data.lastPolledAt != nil)
    }

    @Test("updateDevice preserves userCode in secondary index")
    func updateDevicePreservesUserCode() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        try await storage.updateDevice(
            deviceCode: "dev-code-0001",
            newStatus: .authorized,
            payload: nil,
            lastPolledAt: nil
        )

        let foundByUserCode = await storage.getDevice(byUserCode: "ABCD-EFGH")
        #expect(foundByUserCode != nil)
    }

    @Test("updateDevice with unknown device code throws")
    func updateDeviceUnknownCodeThrows() async throws {
        let storage = AuthCodeStorage(use: .memory)

        do {
            try await storage.updateDevice(
                deviceCode: "nonexistent-code",
                newStatus: .authorized,
                payload: nil,
                lastPolledAt: nil
            )
            Issue.record("Expected error to be thrown for unknown device code")
        } catch {
            // Expected: no matching session found
        }
    }

    // MARK: - delete

    @Test("delete removes device session")
    func deleteDeviceSession() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        try await storage.delete(type: .device, codeValue: "dev-code-0001")

        let found = await storage.get(type: .device, codeValue: "dev-code-0001")
        #expect(found == nil)
    }

    @Test("delete also removes secondary user code lookup")
    func deleteRemovesUserCodeLookup() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession())

        try await storage.delete(type: .device, codeValue: "dev-code-0001")

        let foundByUserCode = await storage.getDevice(byUserCode: "ABCD-EFGH")
        #expect(foundByUserCode == nil)
    }

    @Test("multiple device sessions are stored independently")
    func multipleDeviceSessions() async throws {
        let storage = AuthCodeStorage(use: .memory)
        try await storage.set(authSession: makeDeviceSession(
            deviceCode: "dev-code-AAA1", userCode: "AAAA-BBBB"
        ))
        try await storage.set(authSession: makeDeviceSession(
            deviceCode: "dev-code-BBB1", userCode: "CCCC-DDDD"
        ))

        let firstSession = await storage.getDevice(byUserCode: "AAAA-BBBB")
        let secondSession = await storage.getDevice(byUserCode: "CCCC-DDDD")

        #expect(firstSession != nil)
        #expect(secondSession != nil)
        #expect(firstSession?.codeValue != secondSession?.codeValue)
    }
}
