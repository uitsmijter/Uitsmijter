import Foundation
import XCTVapor
@testable import Server

/// Test the whole Plain Code flow
/// - User is not logged in
/// - Request a authorisation code
/// - Get the login Page
/// - Log in
/// - Gets the code redirect
///
final class AuthControllerCodeInsecureFlowCycleTest: XCTestCase {
    let decoder = JSONDecoder()
    let app = Application(.testing)
    let testAppIdent = UUID()

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent)

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    /// Flow Test
    ///
    /// - Throws: An error if something with the network went wrong
    func testCodeFlowWFullRequestCycle() async throws {

        // 1. Request Code, get Login Page
        // -----------------------------------
        let testServerAddress = "http://\(app.http.server.configuration.hostname):\(app.http.server.configuration.port)"
        let responseAuthRequest = try await app.sendRequest(
                .GET,
                "/authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://example.com/"
                        + "&scope=test"
                        + "&state=123"
        )

        XCTAssertContains(responseAuthRequest.body.string, "<form action=\"/login\" method=\"post\">")

        let locationString = "\(testServerAddress)/authorize"
                + "?response_type=code"
                + "&amp;client_id=\(testAppIdent)"
                + "&amp;redirect_uri=http://example.com/"
                + "&amp;scope=test"
                + "&amp;state=123"
        XCTAssertContains(
                responseAuthRequest.body.string,
                "<input type=\"hidden\" name=\"location\" value=\""
                        + "/authorize"
                        + "?response_type=code"
                        + "&amp;client_id=\(testAppIdent)"
                        + "&amp;redirect_uri=http://example.com/"
                        + "&amp;scope=test"
                        + "&amp;state=123\""
        )

        // no cookie is send here!
        XCTAssertEqual(responseAuthRequest.headers["set-cookie"].count, 0, "There should be no cookie set, yet")

        // 2. Login
        // -----------------------------------
        let responseLoginSubmission = try app.sendRequest(.POST, "/login", beforeRequest: ({ req in
            // fill the form
            try req.content.encode(LoginForm(
                    username: "trumpet@example.com",
                    password: "It Never Entered My Mind",
                    location: locationString
            ))
        }))

        XCTAssertEqual(responseLoginSubmission.status, .seeOther)
        XCTAssertContains(
                responseLoginSubmission.headers["location"].first, "\(testServerAddress)/authorize"
                + "?response_type=code"
                + "&amp;client_id=\(testAppIdent)"
                + "&amp;redirect_uri=http://example.com/"
                + "&amp;scope=test"
                + "&amp;state=123"
        )
        XCTAssertTrue(responseLoginSubmission.headers.contains(name: .setCookie))

        guard let ssoCookie: HTTPCookies.Value = responseLoginSubmission.headers.setCookie?[Constants.COOKIE.NAME]
        else {
            XCTFail("No set cookie header")
            throw Abort(.badRequest)
        }

        // 3. follow the redirect
        // -----------------------------------
        let responseLoginRedirect = try await app.sendRequest(
                .GET,
                "/authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent)"
                        + "&redirect_uri=http://example.com/"
                        + "&scope=test&state=123",
                headers: ["Cookie": ssoCookie.serialize(name: Constants.COOKIE.NAME)])

        // 4. Get the second redirect with the code
        // -----------------------------------
        XCTAssertEqual(responseLoginRedirect.status, .seeOther)
        // XCTAssertTrue(responseLoginRedirect.headers.contains(name: .setCookie))
        XCTAssertTrue(responseLoginRedirect.headers.contains(name: .location))
        XCTAssertTrue(responseLoginRedirect.headers.contains(name: .authorization))

        XCTAssertGreaterThan(responseLoginRedirect.headers.bearerAuthorization?.token.count ?? 0, 8)
        guard let location = responseLoginRedirect.headers.first(name: "location") else {
            XCTFail("Con not get location from headers")
            throw Abort(.badRequest)
        }
        XCTAssertContains(location, "example.com")
        XCTAssertContains(location, "code=")
        XCTAssertContains(location, "state=123")

        let codeGroups = try location.groups(regex: "code=([a-zA-Z0-9]+)")
        XCTAssertEqual(codeGroups.count, 2)
        let code = codeGroups[1]
        XCTAssertEqual(code.count, Constants.TOKEN.LENGTH)
    }

}
