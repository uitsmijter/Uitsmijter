@testable import Server
import XCTVapor

final class HealthTests: XCTestCase {

    func testGetHealth() async throws {
        let app = Application(.testing)
        defer {
            app.shutdown()
        }
        try configure(app)

        try app.test(.GET, "health", afterResponse: { res in
            XCTAssertEqual(res.status, .noContent)
        })
    }
}
