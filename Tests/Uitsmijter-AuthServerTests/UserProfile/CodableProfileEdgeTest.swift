import Testing
@testable import Uitsmijter_AuthServer
import Foundation

/// Tests for CodableProfile edge cases, error handling, and Sendable conformance
@Suite("CodableProfile Edge Cases Tests")
struct CodableProfileEdgeTest {

    // MARK: - Edge Cases

    @Test("Decode empty array")
    func decodeEmptyArray() throws {
        let json = Data("[]".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.array?.isEmpty == true)
    }

    @Test("Decode empty object")
    func decodeEmptyObject() throws {
        let json = Data("{}".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.object?.isEmpty == true)
    }

    @Test("Decode empty string")
    func decodeEmptyString() throws {
        let json = Data("\"\"".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.string == "")
    }

    @Test("Decode zero integer")
    func decodeZeroInteger() throws {
        let json = Data("0".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.int == 0)
    }

    @Test("Decode zero double")
    func decodeZeroDouble() throws {
        let json = Data("0.0".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        // Note: JSON "0.0" is actually decoded as integer 0, not double 0.0
        // This is because JSONDecoder tries integer first
        #expect(profile.int == 0)
    }

    @Test("Decode negative integer")
    func decodeNegativeInteger() throws {
        let json = Data("-42".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.int == -42)
    }

    @Test("Decode negative double")
    func decodeNegativeDouble() throws {
        let json = Data("-42.5".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.double == -42.5)
    }

    @Test("Decode very large integer")
    func decodeVeryLargeInteger() throws {
        let json = Data("9223372036854775807".utf8)  // Int.max
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.int == 9_223_372_036_854_775_807)
    }

    @Test("Decode string with special characters")
    func decodeStringWithSpecialChars() throws {
        let json = Data("\"hello\\nworld\\t!\"".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.string == "hello\nworld\t!")
    }

    @Test("Decode string with unicode")
    func decodeStringWithUnicode() throws {
        let json = Data("\"Hello 🌍\"".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.string == "Hello 🌍")
    }

    @Test("Decode array with null values")
    func decodeArrayWithNulls() throws {
        let json = Data("[1,null,3]".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.array?.count == 3)
        #expect(profile.array?[0].int == 1)
        #expect(profile.array?[1].isNil == true)
        #expect(profile.array?[2].int == 3)
    }

    @Test("Decode object with null values")
    func decodeObjectWithNulls() throws {
        let json = Data("{\"name\":\"John\",\"age\":null}".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.object?["name"]?.string == "John")
        #expect(profile.object?["age"]?.isNil == true)
    }

    @Test("Decode array with mixed types")
    func decodeArrayWithMixedTypes() throws {
        let json = Data("[1,\"two\",3.5,true,null]".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.array?.count == 5)
        #expect(profile.array?[0].int == 1)
        #expect(profile.array?[1].string == "two")
        #expect(profile.array?[2].double == 3.5)
        #expect(profile.array?[3].bool == true)
        #expect(profile.array?[4].isNil == true)
    }

    // MARK: - Error Handling Tests

    @Test("Decode invalid JSON throws error")
    func decodeInvalidJSON() throws {
        let json = Data("invalid".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CodableProfile.self, from: json)
        }
    }

    @Test("Decode incomplete JSON throws error")
    func decodeIncompleteJSON() throws {
        let json = Data("{\"name\":".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CodableProfile.self, from: json)
        }
    }

    // MARK: - Sendable Conformance Tests

    @Test("CodableProfile conforms to Sendable")
    func conformsToSendable() throws {
        let profile = CodableProfile.string("test")

        // Sendable conformance is compile-time checked
        Task {
            _ = profile.string
        }

        #expect(profile.string == "test")
    }

    @Test("CodableProfile array with Sendable conformance")
    func arraySendableConformance() throws {
        let profile = CodableProfile.array([.string("a"), .integer(1)])

        Task {
            _ = profile.array
        }

        #expect(profile.array?.count == 2)
    }

    @Test("CodableProfile object with Sendable conformance")
    func objectSendableConformance() throws {
        let profile = CodableProfile.object(["name": .string("John")])

        Task {
            _ = profile.object
        }

        #expect(profile.object?["name"]?.string == "John")
    }
}
