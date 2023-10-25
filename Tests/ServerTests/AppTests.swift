@testable import Server
import XCTVapor

enum TestError: Error {
    case abort
    case fail(withError: String)
}

final class AppTests: XCTestCase {
    func testHelloWorld() throws {
        let app = Application(.testing)
        defer {
            app.shutdown()
        }
        try configure(app)

        try app.test(.GET, "", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }
}
