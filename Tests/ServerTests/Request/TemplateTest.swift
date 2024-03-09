import Foundation
import XCTVapor
@testable import Server

final class TemplateTest: XCTestCase {

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

    func testWithoutLogin() {
        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "-"]
        request.clientInfo = SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "index", request: request)
        XCTAssertEqual(result, "default/error")
    }

    func testWithHeaderFallbackToDefault() {
        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "example.com"]
        request.clientInfo = SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "index", request: request)
        XCTAssertEqual(result, "default/index")
    }

    func testWithUnknownHeader() async {
        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "example.org"]
        request.clientInfo = SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "index", request: request)
        XCTAssertEqual(result, "default/error")
    }

    func testWithHeaderToUnknownFallbackToDefault() {
        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "example.com"]
        request.clientInfo = SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "not_exists", request: request)
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
}
