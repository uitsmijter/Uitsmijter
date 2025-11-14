import Testing
@testable import FoundationExtensions

@Suite("String Regex Extension Tests")
struct StringRegexTest {

    @Test("Match groups full string")
    func matchGroupsFull() throws {
        let results = try "Hello".groups(regex: "^.+$")
        #expect(results.count == 1)
        #expect(results.first == "Hello")
    }

    @Test("Match groups with options")
    func matchGroupsOptions() throws {
        let results = try "Hello".groups(regex: #"^(h|H)e(ll)o$"#)
        #expect(results.count == 2)
        #expect(results.first == "H")
    }

    @Test("Match groups with selections")
    func matchGroupsSelections() throws {
        let results = try "The 1 number".groups(regex: #"^The\s+(.+)\s+number$"#)
        #expect(results.count == 1)
        #expect(results.first == "1")
    }

    @Test("Match groups with multiple selections")
    func matchGroupsMultipleSelections() throws {
        let results = try "The 1 number is fine".groups(regex: #"^The\s+(.+)\s+number\s+is\s+(.+)$"#)
        #expect(results.count == 2)
        #expect(results.first == "1")
        #expect(results.last == "fine")
    }
}
