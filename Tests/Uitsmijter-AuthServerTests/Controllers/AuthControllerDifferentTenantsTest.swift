import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Auth Controller Different Tenants Test", .serialized)
struct AuthControllerDifferentTenantsTest {
    let testAppIdent1 = UUID()
    let testAppIdent2 = UUID()

    @Test("Created expected set") func createdExpectedSet() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage, uuids: [testAppIdent1, testAppIdent2], script: .johnDoe
            )

            #expect(await app.entityStorage.tenants.count >= 2)
            #expect(await app.entityStorage.clients.count >= 2)
        }
    }

    @Test("Can login insecure with correct client") func canLoginInsecureWithCorrectClient() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage, uuids: [testAppIdent1, testAppIdent2], script: .johnDoe
            )
            guard let tenant = await app.entityStorage.clients.first(where: { $0.config.ident == testAppIdent1 }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }
            let response = try await app.sendRequest(
                .GET,
                "authorize?"
                    + "response_type=code"
                    + "&client_id=\(testAppIdent1.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                }
            )
            #expect(response.status == .seeOther)
        }
    }

    @Test("Can login PKCE with correct client") func canLoginPKCEWithCorrectClient() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage, uuids: [testAppIdent1, testAppIdent2], script: .johnDoe
            )
            guard let tenant = await app.entityStorage.clients.first(where: { $0.config.ident == testAppIdent1 }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            let response = try await app.sendRequest(
                .GET,
                "authorize?"
                    + "response_type=code"
                    + "&client_id=\(testAppIdent1.uuidString)"
                    + "&redirect_uri=http://localhost/&scope=test"
                    + "&state=123"
                    + "&code_challenge=aem5AeKo"
                    + "&code_challenge_method=plain",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                })
            #expect(response.status == .seeOther)
        }
    }

    @Test("Can not login insecure with authentication from other tenant")
    func canNotLoginInsecureWithAuthenticationFromOtherTenant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage, uuids: [testAppIdent1, testAppIdent2], script: .johnDoe
            )
            guard let tenant = await app.entityStorage.clients.first(where: { $0.config.ident == testAppIdent1 }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            let response = try await app.sendRequest(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent2.uuidString)"
                    + "&redirect_uri=http://localhost/&scope=test&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                }
            )
            #expect(response.status == .forbidden)
        }
    }

    @Test("Can not login PKCE with authentication from other tenant")
    func canNotLoginPKCEWithAuthenticationFromOtherTenant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage, uuids: [testAppIdent1, testAppIdent2], script: .johnDoe
            )
            guard let tenant = await app.entityStorage.clients.first(where: { $0.config.ident == testAppIdent1 }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            let response = try await app.sendRequest(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent2.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "&code_challenge=aem5AeKo"
                    + "&code_challenge_method=plain",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                })
            #expect(response.status == .forbidden)
        }
    }

}
