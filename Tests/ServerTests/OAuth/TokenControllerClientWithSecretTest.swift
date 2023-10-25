import Foundation
import XCTVapor
@testable import Server

final class TokenControllerClientWithSecretTest: XCTestCase {
    let testAppIdent = UUID()
    let testSecret = String.random(length: 12)
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClientWithSecret(
                uuid: testAppIdent,
                includeGrantTypes: [.password],
                secret: testSecret
        )

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    // MARK: - Password Flow

    /// We only need to test password in the first place, because client check happens right at the beginning.
    /// For further versions other types should be checked too, in case of some refactoring

    func testTokenPasswordFlowEnsureClient() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: testSecret,
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
        XCTAssertEqual((content.expires_in ?? 0) / 60 / 60, Constants.TOKEN.EXPIRATION_HOURS)
        XCTAssertGreaterThan(content.access_token.count, 64)
    }

    func testPasswordFlowNoClientSecret() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    username: "valid_user",
                    password: "valid_password"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .unauthorized)
    }

    func testPasswordFlowWrongClientSecret() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: "_I_AM_WRONG_IN_ANY_CIRCUMSTANCES",
                    username: "valid_user",
                    password: "valid_password"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .unauthorized)
    }
}
