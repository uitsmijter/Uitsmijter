import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@Suite("Subject Tests")
@MainActor
struct SubjectTest {

    @Test("Create subject with string")
    func createSubject() {
        let sub: Subject = Subject(subject: "Hello")
        #expect(sub.subject == "Hello")
    }

    @Test("Construct subjects from JSON")
    func constructSubjectsFromJson() {
        let input = [
            "{",
            "{}",
            "{\"foo\": \"bar\"}",
            "{\"subject\": \"me@example.com\"}",
            "{\"ok\": 1, \"subject\": \"me@example.com\"}",
            "{\"err\": 0}"
        ]
        let subs = Subject.decode(from: input)
        #expect(subs.count == 2)
        #expect(subs.first?.subject == "me@example.com")
    }
}
