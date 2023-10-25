@testable import Server
import XCTVapor

final class StringRegexTest: XCTestCase {

    func testMatchGroupsFull() throws {
        let results = try "Hello".groups(regex: "^.+$")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, "Hello")
    }

    func testMatchGroupsOptions() throws {
        let results = try "Hello".groups(regex: #"^(h|H)e(ll)o$"#)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first, "H")
    }

    func testMatchGroupsSelections() throws {
        let results = try "The 1 number".groups(regex: #"^The\s+(.+)\s+number$"#)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, "1")
    }

    func testMatchGroupsMultipleSelections() throws {
        let results = try "The 1 number is fine".groups(regex: #"^The\s+(.+)\s+number\s+is\s+(.+)$"#)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first, "1")
        XCTAssertEqual(results.last, "fine")
    }
}
