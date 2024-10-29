import Foundation
import XCTVapor
@testable import Server

final class AuthControllerCodeGenericTests: XCTestCase {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()
    let app: Application = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent)

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCodeFlowWithoutParametersShouldFail() throws {
        try app.test(.GET, "authorize", afterResponse: { res in
            let err = try decoder.decode(ResponseError.self, from: res.body)
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContains(err.reason, "Value of type 'String'")
        })
    } 

    func testUnknownCodeChallengeShouldFail() throws {
        let response = try app.sendRequest(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge_method=nonexistent",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "Unknown")
                }
        )
        XCTAssertEqual(response.status, .notImplemented)
    }

    func testWithWrongCodeShouldFail() throws {
        _ = try getCode(application: app, clientUUID: testAppIdent, challenge: "", method: .none)
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: "________________").value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testShouldNotUseACodeTwice() throws {
        let code = try getCode(application: app, clientUUID: testAppIdent, challenge: "", method: .none)
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
        let accessToken = try response.content.decode(TokenResponse.self)
        XCTAssertEqual(accessToken.token_type, .Bearer)

        let secondResponse = try app.sendRequest(.POST, "/token", beforeRequest: { req in
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
        XCTAssertEqual(secondResponse.status, .forbidden)
    }

}
