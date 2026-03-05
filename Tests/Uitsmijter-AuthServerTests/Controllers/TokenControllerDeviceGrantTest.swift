import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@Suite("Token Controller Device Grant Tests", .serialized)
struct TokenControllerDeviceGrantTest {
    let testAppIdent = UUID()

    // MARK: - Helpers

    private func makeDeviceTokenRequest(
        clientId: String,
        deviceCode: String
    ) -> DeviceTokenRequest {
        DeviceTokenRequest(
            grant_type: .device_code,
            client_id: clientId,
            client_secret: nil,
            device_code: deviceCode
        )
    }

    private func seedPendingSession(in storage: AuthCodeStorage, deviceCode: String, clientId: String) async throws {
        let session = AuthSession.device(DeviceSession(
            clientId: clientId,
            deviceCode: Code(value: deviceCode),
            userCode: "ABCD-1234",
            scopes: ["read"],
            payload: nil,
            status: .pending
        ))
        try await storage.set(authSession: session)
    }

    private func makeTestPayload(clientId: String, tenantName: String) -> Payload {
        let expirationDate = Date(timeIntervalSinceNow: 90 * 86_400)
        return Payload(
            issuer: IssuerClaim(value: "https://localhost"),
            subject: "valid_user",
            audience: AudienceClaim(value: clientId),
            expiration: ExpirationClaim(value: expirationDate),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: tenantName,
            role: "user",
            user: "valid_user",
            scope: "read"
        )
    }

    // MARK: - Tests

    @Test("Device token grant with unknown device code returns bad request")
    func deviceTokenUnknownDeviceCode() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = self.makeDeviceTokenRequest(
                        clientId: self.testAppIdent.uuidString,
                        deviceCode: "nonexistent-device-code-01"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("Device token grant with pending status returns bad request")
    func deviceTokenPendingStatusReturnsBadRequest() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }
            let knownDeviceCode = "pending-device-code-001"
            try await seedPendingSession(
                in: storage,
                deviceCode: knownDeviceCode,
                clientId: testAppIdent.uuidString
            )

            let response = try await app.sendRequest(
                .POST, "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = self.makeDeviceTokenRequest(
                        clientId: self.testAppIdent.uuidString,
                        deviceCode: knownDeviceCode
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("Device token grant with denied status returns bad request")
    func deviceTokenDeniedStatusReturnsBadRequest() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }
            let knownDeviceCode = "denied-device-code-001"
            let session = AuthSession.device(DeviceSession(
                clientId: testAppIdent.uuidString,
                deviceCode: Code(value: knownDeviceCode),
                userCode: "DENI-EDDD",
                scopes: ["read"],
                payload: nil,
                status: .denied
            ))
            try await storage.set(authSession: session)

            let response = try await app.sendRequest(
                .POST, "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = self.makeDeviceTokenRequest(
                        clientId: self.testAppIdent.uuidString,
                        deviceCode: knownDeviceCode
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("Device token grant with authorized status returns access token")
    func deviceTokenAuthorizedStatusReturnsAccessToken() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }

            let knownDeviceCode = "authorized-device-code-1"
            let payload = makeTestPayload(
                clientId: testAppIdent.uuidString,
                tenantName: "Test Tenant"
            )
            let session = AuthSession.device(DeviceSession(
                clientId: testAppIdent.uuidString,
                deviceCode: Code(value: knownDeviceCode),
                userCode: "AUTH-ORZE",
                scopes: ["read"],
                payload: payload,
                status: .authorized
            ))
            try await storage.set(authSession: session)

            let response = try await app.sendRequest(
                .POST, "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = self.makeDeviceTokenRequest(
                        clientId: self.testAppIdent.uuidString,
                        deviceCode: knownDeviceCode
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .ok)
            guard let tokenResponse = try? response.content.decode(TokenResponse.self) else {
                Issue.record("Failed to decode TokenResponse")
                return
            }
            #expect(tokenResponse.access_token.count > 64)
            #expect(tokenResponse.token_type == .Bearer)
            #expect(tokenResponse.expires_in != nil)
        }
    }

    @Test("Device token grant with authorized status removes session from storage")
    func deviceTokenAuthorizedDeletesSession() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }

            let knownDeviceCode = "authorized-device-del-1"
            let payload = makeTestPayload(
                clientId: testAppIdent.uuidString,
                tenantName: "Test Tenant"
            )
            let session = AuthSession.device(DeviceSession(
                clientId: testAppIdent.uuidString,
                deviceCode: Code(value: knownDeviceCode),
                userCode: "DELE-TEST",
                scopes: ["read"],
                payload: payload,
                status: .authorized
            ))
            try await storage.set(authSession: session)

            let response = try await app.sendRequest(
                .POST, "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = self.makeDeviceTokenRequest(
                        clientId: self.testAppIdent.uuidString,
                        deviceCode: knownDeviceCode
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .ok)
            let gone = await storage.get(type: .device, codeValue: knownDeviceCode)
            #expect(gone == nil)
        }
    }

    @Test("Device token grant with rapid polling returns slow_down (429)")
    func deviceTokenRapidPollingReturnsTooManyRequests() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }

            let knownDeviceCode = "slow-down-device-code-1"
            let recentPollTime = Date()
            let session = AuthSession.device(DeviceSession(
                clientId: testAppIdent.uuidString,
                deviceCode: Code(value: knownDeviceCode),
                userCode: "SLOW-DOWN",
                scopes: ["read"],
                payload: nil,
                status: .pending,
                lastPolledAt: recentPollTime
            ))
            try await storage.set(authSession: session)

            let response = try await app.sendRequest(
                .POST, "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = self.makeDeviceTokenRequest(
                        clientId: self.testAppIdent.uuidString,
                        deviceCode: knownDeviceCode
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .tooManyRequests)
        }
    }
}
