import Foundation
import XCTVapor
@testable import Server

final class TokenControllerPasswordGrantTest: XCTestCase {
    let testAppIdent = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(
                uuid: testAppIdent,
                includeGrantTypes: [.authorization_code, .refresh_token, .password],
                script: .johnDoe
        )
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testTokenControllerPasswordGrantWrongPass() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    username: "valid_user",
                    password: "not_correct"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testTokenControllerPasswordGrantWrongUser() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    username: "Gustav",
                    password: "valid_password"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testTokenControllerPasswordGrantCorrectCredentials() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    username: "valid_user",
                    password: "valid_password"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .ok)
        let content = try response.content.decode(TokenResponse.self)
        XCTAssertEqual(content.scope, "")
        XCTAssertEqual(content.token_type, .Bearer)
        guard let expires_in = content.expires_in else {
            throw TestError.fail(withError: "Expires in is missing but expected")
        }
        XCTAssertEqual(expires_in / 60 / 60, Constants.TOKEN.EXPIRATION_HOURS)
        XCTAssertGreaterThan(content.access_token.count, 64)
        // tokens issued with the implicit grant cannot be issued a refresh token.
        XCTAssertNil(content.refresh_token)
    }

    func testTokenControllerPasswordGrantCorrectCredentialsWithScopes() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: "read",
                    username: "valid_user",
                    password: "valid_password"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .ok)
        let content = try response.content.decode(TokenResponse.self)
        XCTAssertEqual(content.scope, "read")
        XCTAssertEqual(content.token_type, .Bearer)
        guard let expires_in = content.expires_in else {
            throw TestError.fail(withError: "Expires in is missing but expected")
        }
        XCTAssertEqual(expires_in / 60 / 60, Constants.TOKEN.EXPIRATION_HOURS)
        XCTAssertGreaterThan(content.access_token.count, 64)
        // tokens issued with the implicit grant cannot be issued a refresh token.
        XCTAssertNil(content.refresh_token)
    }
}
