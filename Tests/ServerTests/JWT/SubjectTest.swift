import Foundation
import XCTVapor
@testable import Server

final class SubjectTest: XCTestCase {

    func testCreateSubject() {
        let sub: Subject = Subject(subject: "Hello")
        XCTAssertEqual(sub.subject, "Hello")
    }

    func testConstructSubjectsFromJson() {
        let input = [
            "{",
            "{}",
            "{\"foo\": \"bar\"}",
            "{\"subject\": \"me@example.com\"}",
            "{\"ok\": 1, \"subject\": \"me@example.com\"}",
            "{\"err\": 0}"
        ]
        let subs = Subject.decode(from: input)
        XCTAssertEqual(subs.count, 2)
        XCTAssertEqual(subs.first?.subject, "me@example.com")
    }
}
