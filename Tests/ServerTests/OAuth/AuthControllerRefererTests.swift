import Foundation
import XCTVapor
@testable import Server

final class AuthControllerRefererTests: XCTestCase {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent, referrers: ["http://localhost:8080/"])

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testRedirectToLoginPageOK() async throws {
        let response = try app.sendRequest(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "response_mode=query",
                beforeRequest: { req in
                    req.headers.add(name: "Referer", value: "http://localhost:8080/foo")
                }
        )
        XCTAssertEqual(response.status, .unauthorized)
        XCTAssertContains(response.body.string, "action=\"/login\"")
    }

    func testRedirectToLoginPageFail() async throws {
        let response = try app.sendRequest(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "response_mode=query",
                beforeRequest: { req in
                    req.headers.add(name: "Referer", value: "http://evilhackerssite/hoho")
                }
        )
        XCTAssertEqual(response.status, .forbidden)
        XCTAssertContains(response.body.string, "WRONG_REFERER")
    }

}
