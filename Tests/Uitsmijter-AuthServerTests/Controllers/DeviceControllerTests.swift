import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Device Controller Tests", .serialized)
struct DeviceControllerTests {
    let testAppIdent = UUID()

    // MARK: - POST /oauth/device_authorization

    @Test("Valid device authorization request returns device_code and user_code")
    func deviceAuthorizationReturnsDeviceAndUserCode() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: testAppIdent.uuidString,
                        scope: "read"
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .ok)
            guard let body = try? response.content.decode(DeviceAuthorizationResponse.self) else {
                Issue.record("Failed to decode DeviceAuthorizationResponse")
                return
            }
            #expect(body.device_code.count == 32)
            #expect(body.user_code.count == 9)
            #expect(body.user_code.contains("-"))
            #expect(body.expires_in == 1800)
            #expect(body.interval == 5)
            #expect(!body.verification_uri.isEmpty)
        }
    }

    @Test("Device authorization stores session in storage")
    func deviceAuthorizationStoresSession() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: testAppIdent.uuidString,
                        scope: nil
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .ok)
            guard let body = try? response.content.decode(DeviceAuthorizationResponse.self) else {
                Issue.record("Failed to decode DeviceAuthorizationResponse")
                return
            }

            let stored = await app.authCodeStorage?.get(type: .device, codeValue: body.device_code)
            #expect(stored != nil)
            guard case .device(let deviceData) = stored else {
                Issue.record("Expected device session in storage")
                return
            }
            #expect(deviceData.status == .pending)
            #expect(deviceData.userCode == body.user_code)
        }
    }

    @Test("Device authorization user code has correct XXXX-XXXX format")
    func deviceAuthorizationUserCodeFormat() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: testAppIdent.uuidString,
                        scope: nil
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            guard let body = try? response.content.decode(DeviceAuthorizationResponse.self) else {
                Issue.record("Failed to decode DeviceAuthorizationResponse")
                return
            }
            let parts = body.user_code.components(separatedBy: "-")
            #expect(parts.count == 2)
            #expect(parts[0].count == 4)
            #expect(parts[1].count == 4)
        }
    }

    @Test("Device authorization with unknown client returns not found")
    func deviceAuthorizationUnknownClientReturnsNotFound() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: UUID().uuidString,
                        scope: nil
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .notFound)
        }
    }

    @Test("Device authorization with device_grant_config but device_code not in grant_types returns bad request")
    func deviceAuthorizationGrantConfigPresentButGrantTypeMissing() async throws {
        try await withApp(configure: configure) { app in
            // Client has device_grant_config but device_code is NOT listed in grant_types
            await MainActor.run {
                app.entityStorage.tenants.removeAll()
                app.entityStorage.clients.removeAll()
                let tenant = Tenant(
                    name: "Test Tenant",
                    config: TenantSpec(hosts: ["localhost"])
                )
                app.entityStorage.tenants.insert(tenant)
                app.entityStorage.clients = [
                    Client(
                        name: "Config Without Grant Type",
                        config: ClientSpec(
                            ident: testAppIdent,
                            tenantname: "Test Tenant",
                            redirect_urls: ["http://localhost"],
                            grant_types: ["authorization_code"],
                            device_grant_config: DeviceGrantConfig(
                                expires_in: 1800,
                                interval: 5,
                                verification_uri: nil
                            )
                        )
                    )
                ]
            }

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: testAppIdent.uuidString,
                        scope: nil
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("Device authorization without device_grant_config returns bad request")
    func deviceAuthorizationNoGrantConfigReturnsBadRequest() async throws {
        try await withApp(configure: configure) { app in
            // generateTestClient creates a client WITHOUT device_grant_config
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: testAppIdent.uuidString,
                        scope: nil
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            #expect(response.status == .badRequest)
        }
    }

    @Test("Device authorization verification_uri contains /activate path")
    func deviceAuthorizationVerificationUriContainsActivatePath() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: testAppIdent.uuidString,
                        scope: nil
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            guard let body = try? response.content.decode(DeviceAuthorizationResponse.self) else {
                Issue.record("Failed to decode DeviceAuthorizationResponse")
                return
            }
            #expect(body.verification_uri.contains("/activate"))
        }
    }

    @Test("Device authorization with scope stores scopes in session")
    func deviceAuthorizationWithScopeStoresScope() async throws {
        try await withApp(configure: configure) { app in
            await generateDeviceTestClient(in: app.entityStorage, uuid: testAppIdent, scopes: ["read", "write"])

            let response = try await app.sendRequest(
                .POST, "/oauth/device_authorization",
                beforeRequest: { @Sendable req async throws in
                    let deviceRequest = DeviceAuthorizationRequest(
                        client_id: testAppIdent.uuidString,
                        scope: "read"
                    )
                    try req.content.encode(deviceRequest, as: .json)
                    req.headers.contentType = .json
                }
            )

            guard let body = try? response.content.decode(DeviceAuthorizationResponse.self) else {
                Issue.record("Failed to decode DeviceAuthorizationResponse")
                return
            }
            let stored = await app.authCodeStorage?.get(type: .device, codeValue: body.device_code)
            guard case .device(let deviceData) = stored else {
                Issue.record("Expected device session in storage")
                return
            }
            #expect(deviceData.scopes.contains("read"))
        }
    }
}
