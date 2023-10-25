import Foundation
import XCTVapor
@testable import Server

final class TemplateLoginTest: XCTestCase {

    let testAppIdent = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent)

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testWithLogin() async throws {
        let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
        let tokenResponse = try getToken(for: code)
        XCTAssertNotNil(tokenResponse.access_token)

        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = [
            "Authorisation": "Bearer \(tokenResponse.access_token)",
            "X-Forwarded-Host": "localhost"
        ]

        request.clientInfo = try clientInfo(on: request)

        let result = Template.getPath(page: "index", request: request)
        XCTAssertEqual(result, "default/index")
    }

    // MARK: - Privates

    private func getToken(for code: String) throws -> TokenResponse {
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
        return try response.content.decode(TokenResponse.self)
    }

    // TODO: used in multiple files, refactor!
    private func clientInfo(on request: Request) throws -> ClientInfo {

        return ClientInfo(
                mode: .interceptor,
                requested: ClientInfoRequest(
                        scheme: request.url.scheme ?? "http",
                        host: request.headers.first(name: "X-Forwarded-Host") ?? "",
                        uri: request.url.path
                ),
                referer: nil,
                responsibleDomain: request.headers.first(name: "X-Forwarded-Host") ?? "",
                serviceUrl: "localhost",
                tenant: Tenant.find(
                        forHost: request.headers.first(name: "X-Forwarded-Host") ?? "_ERROR_"
                ),
                client: nil,
                expired: nil,
                subject: nil,
                validPayload: nil
        )
    }
}
