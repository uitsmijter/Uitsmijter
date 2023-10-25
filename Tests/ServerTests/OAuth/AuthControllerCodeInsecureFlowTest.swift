import Foundation
import XCTVapor
@testable import Server

final class AuthControllerCodeInsecureFlowTest: XCTestCase {
    let decoder = JSONDecoder()
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

    func testValidUsersCodeFlowPlainWithoutSpecification() async throws {
        // get the tenant to save the id into the Payload
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    let contentLength = res.headers["content-length"].first
                    XCTAssertEqual(contentLength, "0")

                    // check location
                    let location = res.headers["location"].first
                    XCTAssertContains(location, "http://localhost/?code=")
                    let locationParts = location?.components(separatedBy: "?")
                    let parameters = locationParts?[1].components(separatedBy: "&")
                    let codeParameter = parameters?.filter({ $0.contains("code=") })
                    let codeParameterPair = codeParameter?.first?.components(separatedBy: "=")
                    let codeValue = codeParameterPair?[1]

                    // check code requirements
                    XCTAssertNotNil(codeValue)
                    XCTAssertEqual(codeValue?.count, 16)

                    // check cookie
//                    let cookie = res.headers["set-cookie"].first
//                    XCTAssertContains(cookie, "uitsmijter=")
//                    XCTAssertContains(cookie, "Max-Age=")
//                    XCTAssertContains(cookie, "Path=/")
//                    XCTAssertContains(cookie, "SameSite=Strict")

                    // check status
                    XCTAssertEqual(res.status, .seeOther)

                    // be sure that it can be used
                    guard let codeValue else {
                        XCTFail("Code is nil")
                        return
                    }
                    let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
                        let tokenRequest = CodeTokenRequest(
                                grant_type: .authorization_code,
                                client_id: testAppIdent.uuidString,
                                client_secret: nil,
                                scope: nil,
                                code: Code(value: codeValue).value
                        )
                        try req.content.encode(tokenRequest, as: .json)
                        req.headers.contentType = .json
                    })
                    XCTAssertEqual(response.status, .ok)
                    let accessToken = try response.content.decode(TokenResponse.self)
                    XCTAssertNotNil(accessToken.access_token)
                    XCTAssertNotNil(accessToken.refresh_token)
                }
        )
    }

    func testUnknownUsersCodeFlowNoneExplicitSpecification_NotLoggedIn() async throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge_method=none",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "Unknown")
                },
                afterResponse: { res in
                    let contentLength = res.headers["content-length"].first
                    XCTAssertGreaterThan(Int16(contentLength ?? "0") ?? 0, 0)
                    XCTAssertContains(res.body.string, "login")
                    XCTAssertContains(res.body.string, "username")
                    XCTAssertContains(res.body.string, "type=\"password\"")
                    XCTAssertContains(res.body.string, "submit")
                }
        )
    }

    func testValidUsersCodeFlowPlainExplicitSpecification() async throws {
        // get the tenant to save the id into the Payload
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge_method=none",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    let contentLength = res.headers["content-length"].first
                    XCTAssertEqual(contentLength, "0")

                    // check location
                    let location = res.headers["location"].first
                    XCTAssertContains(location, "http://localhost/?code=")
                    let locationParts = location?.components(separatedBy: "?")
                    let parameters = locationParts?[1].components(separatedBy: "&")
                    let codeParameter = parameters?.filter({ $0.contains("code=") })
                    let codeParameterPair = codeParameter?.first?.components(separatedBy: "=")
                    let codeValue = codeParameterPair?[1]

                    // check code requirements
                    XCTAssertNotNil(codeValue)
                    XCTAssertEqual(codeValue?.count, 16)

                    // check cookie
//                    let cookie = res.headers["set-cookie"].first
//                    XCTAssertContains(cookie, "uitsmijter=")
//                    XCTAssertContains(cookie, "Max-Age=")
//                    XCTAssertContains(cookie, "Path=/")
//                    XCTAssertContains(cookie, "SameSite=Strict")

                    // check status
                    XCTAssertEqual(res.status, .seeOther)

                    // be sure that it can be used
                    guard let codeValue else {
                        XCTFail("Code is nil")
                        return
                    }
                    let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
                        let tokenRequest = CodeTokenRequest(
                                grant_type: .authorization_code,
                                client_id: testAppIdent.uuidString,
                                client_secret: nil,
                                scope: nil,
                                code: Code(value: codeValue).value
                        )
                        try req.content.encode(tokenRequest, as: .json)
                        req.headers.contentType = .json
                    })
                    XCTAssertEqual(response.status, .ok)
                    let accessToken = try response.content.decode(TokenResponse.self)
                    XCTAssertNotNil(accessToken.access_token)
                    XCTAssertNotNil(accessToken.refresh_token)
                }
        )
    }

}
