@testable import Server
import XCTVapor

final class MetricsTests: XCTestCase {

    func testGetMetrics() async throws {
        let app = Application(.testing)
        defer {
            app.shutdown()
        }
        try configure(app)

        _ = try await app.test(.GET, "health")

        try app.test(.GET, "metrics", beforeRequest: { req in
            req.headers.add(
                    name: "Accept",
                    value: "application/openmetrics-text; version=0.0.1,text/plain;version=0.0.4;q=0.5,*/*;q=0.1"
            )
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)

            XCTAssertContains(res.body.string, "http_requests_total")

            XCTAssertContains(res.body.string, "uitsmijter_tenants_count")
            XCTAssertContains(res.body.string, "uitsmijter_clients_count")

            XCTAssertContains(res.body.string, "uitsmijter_login_attempts")
            XCTAssertContains(res.body.string, "uitsmijter_login_success")
            XCTAssertContains(res.body.string, "uitsmijter_login_failure")

            XCTAssertContains(res.body.string, "uitsmijter_logout")
            XCTAssertContains(res.body.string, "uitsmijter_interceptor_success")
            XCTAssertContains(res.body.string, "uitsmijter_interceptor_failure")

            XCTAssertContains(res.body.string, "uitsmijter_authorize_attempts")
            XCTAssertContains(res.body.string, "uitsmijter_oauth_success")
            XCTAssertContains(res.body.string, "uitsmijter_oauth_failure")

            XCTAssertContains(res.body.string, "uitsmijter_token_stored")
        })
    }
}
