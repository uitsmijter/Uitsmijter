import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

/// Form data for the activation endpoint.
private struct ActivateFormData: Content, Sendable {
    var user_code: String
    var username: String
    var password: String
}

@Suite("Activate Controller Tests", .serialized)
struct ActivateControllerTests {
    let testAppIdent = UUID()

    // MARK: - Helpers

    private func seedPendingDeviceSession(
        in storage: AuthCodeStorage,
        deviceCode: String,
        userCode: String,
        clientId: String
    ) async throws {
        let session = AuthSession.device(DeviceSession(
            clientId: clientId,
            deviceCode: Code(value: deviceCode),
            userCode: userCode,
            scopes: ["read"],
            payload: nil,
            status: .pending
        ))
        try await storage.set(authSession: session)
    }

    // MARK: - GET /activate

    @Test("GET /activate returns ok status")
    func getActivateReturnsOk() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "/activate", afterResponse: { @Sendable res async throws in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("DOCTYPE html"))
            })
        }
    }

    @Test("GET /activate renders the activation form with form element")
    func getActivateRendersForm() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "/activate", afterResponse: { @Sendable res async throws in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("action=\"/activate\""))
            })
        }
    }

    @Test("GET /activate?user_code= prefills the user code field")
    func getActivateWithUserCodeParam() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "/activate?user_code=ABCD-EFGH",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("ABCD-EFGH"))
                }
            )
        }
    }

    // MARK: - POST /activate

    @Test("POST /activate without user_code returns bad request")
    func postActivateMissingUserCode() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/activate",
                beforeRequest: { @Sendable req async throws in
                    req.headers.contentType = .urlEncodedForm
                    req.body = .init(string: "username=valid_user&password=valid_password")
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("POST /activate with invalid user code returns bad request")
    func postActivateInvalidUserCode() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/activate",
                beforeRequest: { @Sendable req async throws in
                    try req.content.encode(
                        ActivateFormData(
                            user_code: "UNKN-OWNN",
                            username: "valid_user",
                            password: "valid_password"
                        ),
                        as: .urlEncodedForm
                    )
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("POST /activate with valid credentials and user code succeeds")
    func postActivateValidCredentials() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent, script: .johnDoe)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }
            let knownUserCode = "VALD-TEST"
            try await seedPendingDeviceSession(
                in: storage,
                deviceCode: "valid-device-code-0001",
                userCode: knownUserCode,
                clientId: testAppIdent.uuidString
            )

            let response = try await app.sendRequest(
                .POST, "/activate",
                beforeRequest: { @Sendable req async throws in
                    try req.content.encode(
                        ActivateFormData(
                            user_code: knownUserCode,
                            username: "valid_user",
                            password: "valid_password"
                        ),
                        as: .urlEncodedForm
                    )
                }
            )

            #expect(response.status == .ok)

            // Session should now be authorized
            let updated = await storage.get(type: .device, codeValue: "valid-device-code-0001")
            guard case .device(let deviceData) = updated else {
                Issue.record("Expected device session to still exist after authorization")
                return
            }
            #expect(deviceData.status == .authorized)
            #expect(deviceData.payload != nil)
        }
    }

    @Test("POST /activate with wrong credentials returns forbidden")
    func postActivateWrongCredentials() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent, script: .johnDoe)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }
            let knownUserCode = "BADC-REDS"
            try await seedPendingDeviceSession(
                in: storage,
                deviceCode: "bad-creds-device-code-01",
                userCode: knownUserCode,
                clientId: testAppIdent.uuidString
            )

            let response = try await app.sendRequest(
                .POST, "/activate",
                beforeRequest: { @Sendable req async throws in
                    try req.content.encode(
                        ActivateFormData(
                            user_code: knownUserCode,
                            username: "valid_user",
                            password: "wrong_password"
                        ),
                        as: .urlEncodedForm
                    )
                }
            )

            #expect(response.status == .forbidden)
        }
    }

    @Test("POST /activate with already-authorized code returns bad request")
    func postActivateAlreadyAuthorizedCode() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent, script: .johnDoe)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }

            let knownUserCode = "ALRD-AUTH"
            // Store with already-authorized status
            let session = AuthSession.device(DeviceSession(
                clientId: testAppIdent.uuidString,
                deviceCode: Code(value: "already-auth-device-001"),
                userCode: knownUserCode,
                scopes: ["read"],
                payload: nil,
                status: .authorized
            ))
            try await storage.set(authSession: session)

            let response = try await app.sendRequest(
                .POST, "/activate",
                beforeRequest: { @Sendable req async throws in
                    try req.content.encode(
                        ActivateFormData(
                            user_code: knownUserCode,
                            username: "valid_user",
                            password: "valid_password"
                        ),
                        as: .urlEncodedForm
                    )
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("POST /activate normalizes user code to uppercase XXXX-XXXX format")
    func postActivateNormalizesUserCode() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent, script: .johnDoe)

            guard let storage = app.authCodeStorage else {
                Issue.record("authCodeStorage not available")
                return
            }
            let knownUserCode = "NORM-ALZE"
            try await seedPendingDeviceSession(
                in: storage,
                deviceCode: "normalize-device-code-001",
                userCode: knownUserCode,
                clientId: testAppIdent.uuidString
            )

            // Submit lower-case without dash — should be normalized to "NORM-ALZE"
            let response = try await app.sendRequest(
                .POST, "/activate",
                beforeRequest: { @Sendable req async throws in
                    try req.content.encode(
                        ActivateFormData(
                            user_code: "normalze",
                            username: "valid_user",
                            password: "valid_password"
                        ),
                        as: .urlEncodedForm
                    )
                }
            )

            // "normalze" is 8 chars → normalized to "NORM-ALZE"
            #expect(response.status == .ok)
        }
    }
}
