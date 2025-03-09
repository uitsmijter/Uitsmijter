@testable import Server
import XCTVapor

final class StringWildcardTest: XCTestCase {

    func testNothingMatch() throws {
        XCTAssertEqual("abc".matchesWildcard(regex: "*.example.com"), false)
    }
    
    func testSubDomainHost() throws {
        XCTAssertEqual("foo.example.com".matchesWildcard(regex: "*.example.com"), true)
        XCTAssertEqual("foo.example.net".matchesWildcard(regex: "*.example.com"), false)
    }
    
    func testInnerHost() throws {
        XCTAssertEqual("foo.example.com".matchesWildcard(regex: "*.*.com"), true)
        XCTAssertEqual("foo.example.net".matchesWildcard(regex: "*.example.*"), true)
    }
    
    func testMultiSubHost() throws {
        XCTAssertEqual("bar.foo.example.com".matchesWildcard(regex: "*.example.com"), false)
    }
}
