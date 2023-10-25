@testable import Server
import XCTVapor

final class LoginControllerFormTests: XCTestCase {

    func testGetLoginPage() async throws {
        let app = Application(.testing)
        defer {
            app.shutdown()
        }
        try configure(app)

        try app.test(.GET, "login", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertContains(res.body.string, "form")
            XCTAssertContains(res.body.string, "name=\"username\"")
            XCTAssertContains(res.body.string, "name=\"password\"")
        })
    }

}
