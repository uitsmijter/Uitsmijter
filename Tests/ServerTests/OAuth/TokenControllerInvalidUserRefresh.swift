import Foundation
import XCTVapor
import JWTKit
@testable import Server

final class TokenControllerInvalidUserRefreshTest: XCTestCase {
    let testAppIdent = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent, script: .juanPerez, scopes: ["read", "list"])

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testTokenControllerInvalidUserNoRefreshTokenGrant() async throws {
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
        XCTAssertEqual(response.status, .forbidden)
        XCTAssertContains(response.body.string, "ERRORS.INVALIDATE")
    }
}
