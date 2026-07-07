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

    /// POST a device_code token request for the test client and return the response.
    private func postDeviceToken(_ app: Application, deviceCode: String) async throws -> TestingHTTPResponse {
        try await app.sendRequest(
            .POST, "/token",
            beforeRequest: { @Sendable req async throws in
                let tokenRequest = self.makeDeviceTokenRequest(
                    clientId: self.testAppIdent.uuidString,
                    deviceCode: deviceCode
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            }
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

            let response = try await postDeviceToken(app, deviceCode: "nonexistent-device-code-01")

            #expect(response.status == .badRequest)
            #expect((try? response.content.decode(OAuthErrorBody.self))?.error == "invalid_grant")
        }
    }

    @Test("Device token grant with pending status returns authorization_pending")
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

            let response = try await postDeviceToken(app, deviceCode: knownDeviceCode)

            #expect(response.status == .badRequest)
            #expect((try? response.content.decode(OAuthErrorBody.self))?.error == "authorization_pending")
        }
    }

    @Test("Device token grant with denied status returns access_denied")
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

            let response = try await postDeviceToken(app, deviceCode: knownDeviceCode)

            #expect(response.status == .badRequest)
            #expect((try? response.content.decode(OAuthErrorBody.self))?.error == "access_denied")
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

            let response = try await postDeviceToken(app, deviceCode: knownDeviceCode)

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

            let response = try await postDeviceToken(app, deviceCode: knownDeviceCode)

            #expect(response.status == .ok)
            let gone = await storage.get(type: .device, codeValue: knownDeviceCode)
            #expect(gone == nil)
        }
    }

    @Test("Device token grant with rapid polling returns slow_down (RFC 8628, HTTP 400)")
    func deviceTokenRapidPollingReturnsSlowDown() async throws {
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

            let response = try await postDeviceToken(app, deviceCode: knownDeviceCode)

            // RFC 8628 §3.5: slow_down is a 400 error with the code in the body,
            // not an HTTP 429.
            #expect(response.status == .badRequest)
            #expect((try? response.content.decode(OAuthErrorBody.self))?.error == "slow_down")
        }
    }

    @Test("Device token grant accepts the RFC 8628 grant_type URN")
    func deviceTokenAcceptsGrantTypeURN() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }

            let knownDeviceCode = "urn-device-code-0001"
            let payload = makeTestPayload(clientId: testAppIdent.uuidString, tenantName: "Test Tenant")
            let session = AuthSession.device(DeviceSession(
                clientId: testAppIdent.uuidString,
                deviceCode: Code(value: knownDeviceCode),
                userCode: "URNU-CODE",
                scopes: ["read"],
                payload: payload,
                status: .authorized
            ))
            try await storage.set(authSession: session)

            // Send the standard form body with the URN grant_type, exactly as a
            // conformant OAuth2 client library would.
            let response = try await app.sendRequest(
                .POST, "/token",
                beforeRequest: { @Sendable req async throws in
                    let form = RawTokenForm(
                        grant_type: GrantTypes.deviceCodeURN,
                        client_id: self.testAppIdent.uuidString,
                        device_code: knownDeviceCode
                    )
                    try req.content.encode(form, as: .urlEncodedForm)
                }
            )

            #expect(response.status == .ok)
            #expect((try? response.content.decode(TokenResponse.self))?.token_type == .Bearer)
        }
    }
}

/// Raw form body letting a test send an arbitrary `grant_type` string (e.g. the
/// RFC 8628 URN), which the typed `DeviceTokenRequest` would otherwise normalize.
private struct RawTokenForm: Content {
    let grant_type: String   // swiftlint:disable:this identifier_name
    let client_id: String    // swiftlint:disable:this identifier_name
    let device_code: String  // swiftlint:disable:this identifier_name
}
