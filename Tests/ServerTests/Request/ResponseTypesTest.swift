import Foundation
import XCTVapor
@testable import Server

final class ResponseTypesTest: XCTestCase {

    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    // MARK: - Login

    func testGetLoginWeb() throws {
        try app.test(
                .GET,
                "login",
                beforeRequest: { req in
                    req.headers.contentType = .html
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .ok)
                    XCTAssertEqual(res.headers.contentType, HTTPMediaType.html)
                }
        )
    }

    func testGetLoginDefault() throws {
        try app.test(
                .GET,
                "login",
                afterResponse: { res in
                    XCTAssertEqual(res.status, .ok)
                    XCTAssertEqual(res.headers.contentType, HTTPMediaType.html)
                }
        )
    }

    // MARK: - Authorize

    func testGetAuthorizeAPI() throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=0"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    req.headers.add(name: "Accept", value: "application/json")
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .badRequest)
                    XCTAssertEqual(res.headers.contentType, HTTPMediaType.json)
                }
        )
    }

    func testGetAuthorizeWeb() throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=0"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    req.headers.add(name: "Accept", value: "text/html")
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .badRequest)
                    XCTAssertEqual(res.headers.contentType, HTTPMediaType.html)
                }
        )
    }

    func testGetAuthorizeDefault() throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=0"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                afterResponse: { res in
                    XCTAssertEqual(res.status, .badRequest)
                    XCTAssertEqual(res.headers.contentType, HTTPMediaType.json)
                }
        )
    }
}
