import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Token Controller Different Tenants Test", .serialized)
struct TokenControllerDifferentTenantsTest {
    let testAppIdent1 = UUID()
    let testAppIdent2 = UUID()

    @Test("Created expected set")
    func createdExpectedSet() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage,
                uuids: [testAppIdent1, testAppIdent2],
                script: .johnDoe
            )

            #expect(await app.entityStorage.tenants.count >= 2)
            #expect(await app.entityStorage.clients.count >= 2)
        }
    }

    @Test("Can login with correct client")
    func canLoginWithCorrectClient() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage,
                uuids: [testAppIdent1, testAppIdent2],
                script: .johnDoe
            )
            // select
            let tenant = await app.entityStorage.tenants.first { element in
                element.config.hosts.contains("127.0.0.1")
            }
            let tenantName = tenant?.name
            let client = await app.entityStorage.clients.first { element in
                element.config.tenantname == tenantName
            }
            #expect(tenant != nil)
            #expect(client != nil)

            guard let client else {
                Issue.record("Client is nil")
                return
            }

            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: client.config.ident)
            #expect(code.count == Constants.TOKEN.LENGTH)

            let clientIdentString = client.config.ident.uuidString
            try await app.testing().test(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: clientIdentString,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .ok)
                let accessToken = try response.content.decode(TokenResponse.self)
                #expect(accessToken.token_type == .Bearer)
                #expect(accessToken.refresh_token != nil)
            })
        }
    }

    @Test("Can not login with code from other tenant")
    func canNotLoginWithCodeFromOtherTenant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage,
                uuids: [testAppIdent1, testAppIdent2],
                script: .johnDoe
            )
            // select
            let tenant = await app.entityStorage.tenants.first { thisTenant in
                thisTenant.config.hosts.contains("127.0.0.1")
            }
            let tenantName = tenant?.name
            let firstClient = await app.entityStorage.clients.first { thisClient in
                thisClient.config.tenantname == tenantName
            }
            let lastClient = await app.entityStorage.clients.first { thisClient in
                thisClient.config.ident != firstClient?.config.ident
            }
            #expect(tenant != nil)
            #expect(firstClient != nil)
            #expect(lastClient != nil)

            guard let firstClient, let lastClient else {
                Issue.record("firstClient is nil or lastClient is nil")
                return
            }

            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: firstClient.config.ident)
            #expect(code.count == Constants.TOKEN.LENGTH)

            let lastClientIdentString = lastClient.config.ident.uuidString
            try await app.testing().test(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: lastClientIdentString,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            }, afterResponse: { @Sendable response async in
                #expect(response.status == .forbidden)
            })
        }
    }

    @Test("Can not get refresh token from other tenant")
    func canNotGetRefreshTokenFromOtherTenant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage,
                uuids: [testAppIdent1, testAppIdent2],
                script: .johnDoe
            )
            // select
            let tenant = await app.entityStorage.tenants.first { thisTenant in
                thisTenant.config.hosts.contains("127.0.0.1")
            }
            let tenantName = tenant?.name
            let firstClient = await app.entityStorage.clients.first { thisClient in
                thisClient.config.tenantname == tenantName
            }
            let lastClient = await app.entityStorage.clients.first { thisClient in
                thisClient.config.ident != firstClient?.config.ident
            }
            #expect(tenant != nil)
            #expect(firstClient != nil)
            #expect(lastClient != nil)

            guard let firstClient, let lastClient else {
                Issue.record("firstClient is nil or lastClient is nil")
                return
            }

            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: firstClient.config.ident)
            let firstClientIdentString = firstClient.config.ident.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: firstClientIdentString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .ok)
            let tokenResponse = try response.content.decode(TokenResponse.self)

            #expect(tokenResponse.refresh_token != nil)
            guard let refreshToken = tokenResponse.refresh_token else {
                Issue.record("No refresh token")
                return
            }

            let lastClientIdentString = lastClient.config.ident.uuidString
            try await app.testing().test(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: lastClientIdentString,
                    client_secret: nil,
                    refresh_token: refreshToken
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            }, afterResponse: { @Sendable response async in
                #expect(response.body.string.contains("TENANT_MISMATCH"))
                #expect(response.status == .forbidden)
            })
        }
    }
}
