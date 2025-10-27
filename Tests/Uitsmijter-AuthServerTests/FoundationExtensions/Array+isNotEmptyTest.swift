import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@Suite("Array isNotEmpty Extension Tests")
struct ArrayIsNotEmptyTest {

    @Test("isNotEmpty returns true for array with elements")
    func isNotEmptyReturnsTrueForNonEmptyArray() {
        let array = [1, 2, 3]
        #expect(array.isNotEmpty == true)
    }

    @Test("isNotEmpty returns false for empty array")
    func isNotEmptyReturnsFalseForEmptyArray() {
        let array: [Int] = []
        #expect(array.isNotEmpty == false)
    }

    @Test("isNotEmpty works with single element")
    func isNotEmptyWorksWithSingleElement() {
        let array = [42]
        #expect(array.isNotEmpty == true)
    }

    @Test("isNotEmpty works with different types - Strings")
    func isNotEmptyWorksWithStrings() {
        let emptyStrings: [String] = []
        let nonEmptyStrings = ["hello", "world"]

        #expect(emptyStrings.isNotEmpty == false)
        #expect(nonEmptyStrings.isNotEmpty == true)
    }

    @Test("isNotEmpty works with different types - Optionals")
    func isNotEmptyWorksWithOptionals() {
        let emptyOptionals: [Int?] = []
        let nonEmptyOptionals: [Int?] = [nil, 1, nil]

        #expect(emptyOptionals.isNotEmpty == false)
        #expect(nonEmptyOptionals.isNotEmpty == true)
    }

    @Test("isNotEmpty works with custom types")
    func isNotEmptyWorksWithCustomTypes() {
        struct Person {
            let name: String
        }

        let emptyPeople: [Person] = []
        let nonEmptyPeople = [Person(name: "Alice"), Person(name: "Bob")]

        #expect(emptyPeople.isNotEmpty == false)
        #expect(nonEmptyPeople.isNotEmpty == true)
    }

    @Test("isNotEmpty can be used in conditional statements")
    func isNotEmptyInConditionals() {
        let items = [1, 2, 3]
        var executed = false

        if items.isNotEmpty {
            executed = true
        }

        #expect(executed == true)
    }

    @Test("isNotEmpty negation equals isEmpty")
    func isNotEmptyNegationEqualsIsEmpty() {
        let emptyArray: [Int] = []
        let nonEmptyArray = [1, 2, 3]

        #expect(emptyArray.isNotEmpty == !emptyArray.isEmpty)
        #expect(nonEmptyArray.isNotEmpty == !nonEmptyArray.isEmpty)
    }

    @Test("isNotEmpty works after array mutations")
    func isNotEmptyWorksAfterMutations() {
        var array: [String] = []
        #expect(array.isNotEmpty == false)

        array.append("first")
        #expect(array.isNotEmpty == true)

        array.removeAll()
        #expect(array.isNotEmpty == false)
    }

    @Test("isNotEmpty works with large arrays")
    func isNotEmptyWorksWithLargeArrays() {
        let largeArray = Array(repeating: 0, count: 10_000)
        #expect(largeArray.isNotEmpty == true)
    }
}
