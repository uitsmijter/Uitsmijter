import Foundation
import XCTVapor
@testable import Server

final class TokenControllerDifferentTenantsTest: XCTestCase {
    let testAppIdent1 = UUID()
    let testAppIdent2 = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()

        generateTestClientsWithMultipleTenants(uuids: [testAppIdent1, testAppIdent2], script: .johnDoe)
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCreatedExpectedSet() {
        XCTAssertGreaterThanOrEqual(EntityStorage.shared.tenants.count, 2)
        XCTAssertGreaterThanOrEqual(EntityStorage.shared.clients.count, 2)
    }

    func testCanLoginWithCorrectClient() async throws {
        // select
        let tenant = EntityStorage.shared.tenants.first { element in
            element.config.hosts.contains("127.0.0.1")
        }
        let client = EntityStorage.shared.clients.first { element in
            element.config.tenant?.name == tenant?.name
        }
        XCTAssertNotNil(tenant)
        XCTAssertNotNil(client)

        guard let client else {
            XCTFail("Client is nil")
            return
        }

        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: client.config.ident)
        XCTAssertEqual(code.count, Constants.TOKEN.LENGTH)

        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: client.config.ident.uuidString,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .ok)
        let accessToken = try response.content.decode(TokenResponse.self)
        XCTAssertEqual(accessToken.token_type, .Bearer)
        XCTAssertNotNil(accessToken.refresh_token)
    }

    func testCanNotLoginWithWithCodeFromOtherTenant() async throws {
        // select
        let tenant = EntityStorage.shared.tenants.first { thisTenant in
            thisTenant.config.hosts.contains("127.0.0.1")
        }
        let firstClient = EntityStorage.shared.clients.first { thisClient in
            thisClient.config.tenant?.name == tenant?.name
        }
        let lastClient = EntityStorage.shared.clients.first { thisClient in
            thisClient.config.ident != firstClient?.config.ident
        }
        XCTAssertNotNil(tenant)
        XCTAssertNotNil(firstClient)
        XCTAssertNotNil(lastClient)

        guard let firstClient, let lastClient else {
            XCTFail("firstClient is nil or lastClient is nil")
            return
        }

        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: firstClient.config.ident)
        XCTAssertEqual(code.count, Constants.TOKEN.LENGTH)

        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: lastClient.config.ident.uuidString,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testCanNotGetRefreshTokenFromOtherTenant() async throws {
        // select
        let tenant = EntityStorage.shared.tenants.first { thisTenant in
            thisTenant.config.hosts.contains("127.0.0.1")
        }
        let firstClient = EntityStorage.shared.clients.first { thisClient in
            thisClient.config.tenant?.name == tenant?.name
        }
        let lastClient = EntityStorage.shared.clients.first { thisClient in
            thisClient.config.ident != firstClient?.config.ident
        }
        XCTAssertNotNil(tenant)
        XCTAssertNotNil(firstClient)
        XCTAssertNotNil(lastClient)

        guard let firstClient, let lastClient else {
            XCTFail("firstClient is nil or lastClient is nil")
            return
        }

        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: firstClient.config.ident)
        let _tokenResponse = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: firstClient.config.ident.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })

        XCTAssertEqual(_tokenResponse.status, .ok)
        let tokenResponse = try _tokenResponse.content.decode(TokenResponse.self)

        XCTAssertNotNil(tokenResponse.refresh_token)
        guard let refreshToken = tokenResponse.refresh_token else {
            XCTFail("No refresh token")
            return
        }

        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: lastClient.config.ident.uuidString,
                    client_secret: nil,
                    refresh_token: refreshToken
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertContains(response.body.string, "TENANT_MISMATCH")
        XCTAssertEqual(response.status, .forbidden)
    }
}
