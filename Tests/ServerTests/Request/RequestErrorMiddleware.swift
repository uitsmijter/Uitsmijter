import Foundation
import XCTVapor
@testable import Server

final class RequestErrorMiddlewareTest: XCTestCase {
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testGetHTMLError() async throws {
        let response = try app.sendRequest(.GET, "/not-found") { (request: inout XCTHTTPRequest) -> Void in
            request.headers.add(name: "Accept", value: "text/html")
        }
        XCTAssertEqual(response.status.code, 404)
        XCTAssertEqual(response.headers.contentType, HTTPMediaType.html)
    }

    func testGetJSONError() async throws {
        let response = try app.sendRequest(.GET, "/not-found") { (request: inout XCTHTTPRequest) -> Void in
            request.headers.add(name: "Accept", value: "application/json")
        }
        XCTAssertEqual(response.status.code, 404)
        XCTAssertEqual(response.headers.contentType, HTTPMediaType.json)
    }
}
