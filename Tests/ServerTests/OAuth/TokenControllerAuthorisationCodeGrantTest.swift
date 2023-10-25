import Foundation
import XCTVapor
import JWTKit
@testable import Server

final class TokenControllerAuthorisationCodeGrantTest: XCTestCase {
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

    func testTokenControllerAuthorisationCodeGrantWrongCode() async throws {
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: "not-a-valid-code").value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    // without scopes

    func testTokenControllerAuthorisationCodeGrant() async throws {
        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)

        // -----------------------------------
        // Get authorisation code
        // -----------------------------------
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .ok)
        let tokenResponse = try response.content.decode(TokenResponse.self)
        XCTAssertEqual(tokenResponse.scope?.count, 0)
        XCTAssertNotNil(tokenResponse.refresh_token)

        let jwt = tokenResponse.access_token
        XCTAssertEqual(tokenResponse.scope, "")

        let payload = try jwt_signer.verify(jwt, as: Payload.self)
        XCTAssertEqual(payload.user, "valid_user")
        XCTAssertEqual(payload.role, "default")
    }

    // with scopes

    func testTokenControllerAuthorisationCodeGrantWithScopes() async throws {
        let code = try await authorisationCodeGrantFlow(
                app: app,
                clientIdent: testAppIdent,
                scopes: ["list", "write", "read", "admin"]
        )

        // -----------------------------------
        // 5b. get authorisation code
        // -----------------------------------
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: "list admin read",
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .ok)
        let tokenResponse = try response.content.decode(TokenResponse.self)
        XCTAssertGreaterThan(tokenResponse.scope?.count ?? 0, 0)
        XCTAssertNotNil(tokenResponse.refresh_token)

        let jwt = tokenResponse.access_token
        XCTAssertContains(tokenResponse.scope, "list")
        XCTAssertContains(tokenResponse.scope, "read")

        let payload = try jwt_signer.verify(jwt, as: Payload.self)
        XCTAssertEqual(payload.user, "valid_user")
        XCTAssertEqual(payload.role, "default")
    }

    // Explicit allowed or not

    func testTokenControllerAuthorisationCodeGrantAllowed() async throws {
        generateTestClient(
                uuid: testAppIdent,
                includeGrantTypes: [.authorization_code],
                script: .johnDoe,
                scopes: ["read", "list"]
        )
        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)

        // -----------------------------------
        // Get authorisation code
        // -----------------------------------
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .ok)
    }

    func testTokenControllerAuthorisationCodeGrantNotAllowed() async throws {
        generateTestClient(
                uuid: testAppIdent,
                includeGrantTypes: [.password],
                script: .johnDoe,
                scopes: ["read", "list"]
        )
        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)

        // -----------------------------------
        // Get authorisation code
        // -----------------------------------
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(response.status, .badRequest)
    }

}
