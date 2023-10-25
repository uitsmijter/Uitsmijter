import Foundation
import XCTVapor
import JWTKit
@testable import Server

final class TokenControllerRefreshTokenGrantTest: XCTestCase {
    let testAppIdent = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"])

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testTokenControllerRefreshTokenGrantWrongToken() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    refresh_token: String.random(length: Constants.TOKEN.LENGTH)
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testTokenControllerRefreshTokenGrant() async throws {
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
        XCTAssertEqual(response.status, .ok)

        let newToken = try response.content.decode(TokenResponse.self)
        XCTAssertNotEqual(tokenResponse.access_token, newToken.access_token)
        XCTAssertNotEqual(tokenResponse.refresh_token, newToken.refresh_token)
        XCTAssertEqual(tokenResponse.scope, newToken.scope)
    }

    func testTokenControllerRefreshTokenStillHaveProfileGrant() async throws {
        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
        let tokenResponse = try getToken(app: app, for: code, appIdent: testAppIdent)

        // Access token profile test
        let payload = try jwt_signer.verify(tokenResponse.access_token, as: Payload.self)
        guard let profile = payload.profile else {
            XCTFail("Can not get profile")
            return
        }
        guard let name = profile.object?["name"]?.string as? String else {
            XCTFail("Can not get name from profile")
            return
        }
        XCTAssertEqual(name, "John Doe")

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
        XCTAssertEqual(response.status, .ok)

        let newToken = try response.content.decode(TokenResponse.self)
        XCTAssertNotEqual(tokenResponse.access_token, newToken.access_token)

        // Refresh token profile test
        let payloadRefreshed = try jwt_signer.verify(tokenResponse.access_token, as: Payload.self)
        guard let profile = payloadRefreshed.profile else {
            XCTFail("Can not get profile")
            return
        }
        guard let name = profile.object?["name"]?.string as? String else {
            XCTFail("Can not get name from profile")
            return
        }
        XCTAssertEqual(name, "John Doe")
    }

    func testTokenControllerCanNotRefreshTokenGrantTwice() async throws {
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
        XCTAssertEqual(response.status, .ok)

        let secondResponse = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    refresh_token: refreshToken
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(secondResponse.status, .forbidden)
    }
}
