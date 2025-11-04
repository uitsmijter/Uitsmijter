import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@Suite("Token Controller User Refresh No Provider Test", .serialized)
struct TokenControllerUserRefreshNoProviderTest {
    let testAppIdent = UUID()

    @Test("Token controller invalid user no refresh token grant")
    func tokenControllerInvalidUserNoRefreshTokenGrant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage,
                uuid: testAppIdent,
                script: .ivanIvano,
                scopes: ["read", "list"]
            )
            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
            let tokenResponse = try await getToken(app: app, for: code, appIdent: testAppIdent)
            #expect(tokenResponse.refresh_token != nil)
            guard let refreshToken = tokenResponse.refresh_token else {
                Issue.record("No refresh token")
                return
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
            // should be ok, because the provider is not implemented and we are running in debug mode.
            #expect(response.status == .ok)
        }
    }
}
