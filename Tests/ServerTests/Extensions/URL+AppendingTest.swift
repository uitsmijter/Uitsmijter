//
// aus der Technik, on 30.08.23.
//

import Foundation

@testable import Server
import XCTVapor

final class URLAppendingTest: XCTestCase {

    let queryItem1 = URLQueryItem(name: "foo", value: "bar")
    let queryItem2 = URLQueryItem(name: "baz", value: "boo")

    func testAppendNewQueryParams() throws {
        guard let url = URL(string: "https://example.com") else {
            throw TestError.fail(withError: "no valid url")
        }

        let new: URL = url.appending(queryItems: [queryItem1, queryItem2])
        XCTAssertEqual(new.absoluteString, "https://example.com?foo=bar&baz=boo")
    }

    func testAppendToExistingQueryParams() throws {
        guard let url = URL(string: "https://example.com?hallo=1") else {
            throw TestError.fail(withError: "no valid url")
        }

        let new: URL = url.appending(queryItems: [queryItem1, queryItem2])
        XCTAssertEqual(new.absoluteString, "https://example.com?hallo=1&foo=bar&baz=boo")
    }

    func testAppendQueryParamsWithPort() throws {
        guard let url = URL(string: "https://example.com:8080") else {
            throw TestError.fail(withError: "no valid url")
        }

        let new: URL = url.appending(queryItems: [queryItem1, queryItem2])
        XCTAssertEqual(new.absoluteString, "https://example.com:8080?foo=bar&baz=boo")
    }

    func testAppendQueryParamsToPath() throws {
        guard let url = URL(string: "/foo") else {
            throw TestError.fail(withError: "no valid url")
        }

        let new: URL = url.appending(queryItems: [queryItem2])
        XCTAssertEqual(new.absoluteString, "/foo?baz=boo")
    }
}
