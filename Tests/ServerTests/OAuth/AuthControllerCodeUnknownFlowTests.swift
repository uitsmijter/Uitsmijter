import Foundation
import XCTVapor
@testable import Server

final class AuthControllerCodeUnknownFlowTests: XCTestCase {
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

    func testCodeFlowUnknownChallenge() async throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge_method=unknown",
                afterResponse: { res in
                    XCTAssertEqual(res.status, .notImplemented)
                    XCTAssertContains(res.body.string, "CODE_CHALLENGE_METHOD_NOT_IMPLEMENTED")
                    XCTAssertContains(res.body.string, "\"error\":true")
                }
        )
    }
}
