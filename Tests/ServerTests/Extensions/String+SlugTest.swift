@testable import Server
import XCTVapor

final class StringSlugTest: XCTestCase {

    func testNothingToSlug() throws {
        let results: String? = "hello-7".slug
        XCTAssertEqual(results?.count, 7)
        XCTAssertEqual(results, "hello-7")
    }

    func testSomethingToSlug() throws {
        let results: String? = "Hello_7 What is a / name".slug
        XCTAssertEqual(results, "hello-7-what-is-a-name")
    }
}
