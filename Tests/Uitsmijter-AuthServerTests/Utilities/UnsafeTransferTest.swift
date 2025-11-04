import Foundation
import Testing
@testable import Uitsmijter_AuthServer

/// Tests for UnsafeTransfer utility
@Suite("UnsafeTransfer Tests")
struct UnsafeTransferTest {

    @Test("UnsafeTransfer wraps and unwraps values")
    func wrapAndUnwrapValues() {
        let value = "test value"
        let wrapper = UnsafeTransfer(value)
        #expect(wrapper.wrappedValue == value)
    }

    @Test("UnsafeTransfer works with Int")
    func worksWithInt() {
        let value = 42
        let wrapper = UnsafeTransfer(value)
        #expect(wrapper.wrappedValue == 42)
    }

    @Test("UnsafeTransfer works with custom struct")
    func worksWithCustomStruct() {
        struct TestStruct {
            let name: String
            let value: Int
        }

        let testValue = TestStruct(name: "test", value: 123)
        let wrapper = UnsafeTransfer(testValue)
        #expect(wrapper.wrappedValue.name == "test")
        #expect(wrapper.wrappedValue.value == 123)
    }

    @Test("UnsafeTransfer works with optional values")
    func worksWithOptionalValues() {
        let value: String? = "optional value"
        let wrapper = UnsafeTransfer(value)
        #expect(wrapper.wrappedValue == "optional value")
    }

    @Test("UnsafeTransfer works with nil optional")
    func worksWithNilOptional() {
        let value: String? = nil
        let wrapper = UnsafeTransfer(value)
        #expect(wrapper.wrappedValue == nil)
    }

    @Test("UnsafeTransfer is Sendable")
    func isSendable() async {
        let value = "test"
        let wrapper = UnsafeTransfer(value)

        // This should compile because UnsafeTransfer is Sendable
        await Task {
            #expect(wrapper.wrappedValue == "test")
        }.value
    }

    @Test("UnsafeTransfer can transfer across Task boundaries")
    func canTransferAcrossTaskBoundaries() async {
        struct NonSendable {
            var counter = 0
        }

        let value = NonSendable()
        let wrapper = UnsafeTransfer(value)

        await Task {
            #expect(wrapper.wrappedValue.counter == 0)
        }.value
    }

    @Test("UnsafeTransfer preserves value identity")
    func preservesValueIdentity() {
        class TestClass {
            let id: Int
            init(id: Int) {
                self.id = id
            }
        }

        let original = TestClass(id: 42)
        let wrapper = UnsafeTransfer(original)

        #expect(wrapper.wrappedValue === original)
        #expect(wrapper.wrappedValue.id == 42)
    }

    @Test("UnsafeTransfer works with arrays")
    func worksWithArrays() {
        let array = [1, 2, 3, 4, 5]
        let wrapper = UnsafeTransfer(array)
        #expect(wrapper.wrappedValue == array)
        #expect(wrapper.wrappedValue.count == 5)
    }

    @Test("UnsafeTransfer works with dictionaries")
    func worksWithDictionaries() {
        let dict = ["key1": "value1", "key2": "value2"]
        let wrapper = UnsafeTransfer(dict)
        #expect(wrapper.wrappedValue["key1"] == "value1")
        #expect(wrapper.wrappedValue["key2"] == "value2")
    }
}
