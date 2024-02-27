import Foundation
import XCTVapor
import JWTKit
@testable import Server

final class TokenControllerUserRefreshNoProviderTest: XCTestCase {
    let testAppIdent = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent, script: .ivanIvano, scopes: ["read", "list"])

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testTokenControllerInvalidUserNoRefreshTokenGrant() async throws {
        try XCTSkipIf(true)
        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
        let tokenResponse = try getToken(app: app, for: code, appIdent: testAppIdent)
        XCTAssertNotNil(tokenResponse.refresh_token)
        guard let refreshToken = tokenResponse.refresh_token else {
            XCTFail("No refresh token")
            return
        }

        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    refresh_token: refreshToken
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        // should be ok, because the provider is not implemented and we are running in debug mode.
        XCTAssertEqual(response.status, .ok)
    }
}
