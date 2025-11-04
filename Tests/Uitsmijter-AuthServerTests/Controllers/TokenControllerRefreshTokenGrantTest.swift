import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@Suite("Token Controller Refresh Token Grant Test", .serialized)
struct TokenControllerRefreshTokenGrantTest {
    let testAppIdent = UUID()

    @Test("Token controller refresh token grant wrong token")
    func tokenControllerRefreshTokenGrantWrongToken() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage, uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"] as [String]?
            )
            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    refresh_token: String.random(length: Constants.TOKEN.LENGTH)
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .forbidden)
        }
    }

    @Test("Token controller refresh token grant")
    func tokenControllerRefreshTokenGrant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage, uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"] as [String]?
            )
            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
            let tokenResponse = try await getToken(app: app, for: code, appIdent: testAppIdent)
            #expect(tokenResponse.refresh_token != nil)
            guard let refreshToken = tokenResponse.refresh_token else {
                Issue.record("No refresh token")
                throw TestError.abort
            }

            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    refresh_token: refreshToken
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .ok)

            let newToken = try response.content.decode(TokenResponse.self)
            #expect(tokenResponse.access_token != newToken.access_token)
            #expect(tokenResponse.refresh_token != newToken.refresh_token)
            #expect(tokenResponse.scope == newToken.scope)
        }
    }

    @Test("Token controller refresh token still have profile grant")
    func tokenControllerRefreshTokenStillHaveProfileGrant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage, uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"] as [String]?
            )
            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
            let tokenResponse = try await getToken(app: app, for: code, appIdent: testAppIdent)

            // Access token profile test
            let payload = try jwt_signer.verify(tokenResponse.access_token, as: Payload.self)
            guard let profile = payload.profile else {
                Issue.record("Can not get profile")
                throw TestError.abort
            }
            guard let name = profile.object?["name"]?.string else {
                Issue.record("Can not get name from profile")
                throw TestError.abort
            }
            #expect(name == "John Doe")

            guard let refreshToken = tokenResponse.refresh_token else {
                Issue.record("No refresh token")
                throw TestError.abort
            }
            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    refresh_token: refreshToken
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .ok)

            let newToken = try response.content.decode(TokenResponse.self)
            #expect(tokenResponse.access_token != newToken.access_token)

            // Refresh token profile test
            let payloadRefreshed = try jwt_signer.verify(tokenResponse.access_token, as: Payload.self)
            guard let profileRefreshed = payloadRefreshed.profile else {
                Issue.record("Can not get profile")
                throw TestError.abort
            }
            guard let nameRefreshed = profileRefreshed.object?["name"]?.string as? String else {
                Issue.record("Can not get name from profile")
                throw TestError.abort
            }
            #expect(nameRefreshed == "John Doe")
        }
    }

    @Test("Token controller can not refresh token grant twice")
    func tokenControllerCanNotRefreshTokenGrantTwice() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage, uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"] as [String]?
            )
            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
            let tokenResponse = try await getToken(app: app, for: code, appIdent: testAppIdent)
            #expect(tokenResponse.refresh_token != nil)
            guard let refreshToken = tokenResponse.refresh_token else {
                Issue.record("No refresh token")
                throw TestError.abort
            }

            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    refresh_token: refreshToken
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .ok)

            let secondResponse = try await app.sendRequest(
                .POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    refresh_token: refreshToken
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
                })
            #expect(secondResponse.status == .forbidden)
        }
    }
}
