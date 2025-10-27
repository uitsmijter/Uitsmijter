import Testing
@testable import Uitsmijter_AuthServer
import Foundation

/// Tests for CodableProfile nested structures and round-trip encoding/decoding
@Suite("CodableProfile Nested & Round-trip Tests")
struct CodableProfileNestedTest {

    // MARK: - Nested Structure Tests

    @Test("Decode nested arrays")
    func decodeNestedArrays() throws {
        let json = Data("[[1,2],[3,4]]".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.array?.count == 2)
        #expect(profile.array?[0].array?[0].int == 1)
        #expect(profile.array?[0].array?[1].int == 2)
        #expect(profile.array?[1].array?[0].int == 3)
        #expect(profile.array?[1].array?[1].int == 4)
    }

    @Test("Decode nested objects")
    func decodeNestedObjects() throws {
        let json = Data("{\"user\":{\"name\":\"John\",\"age\":30}}".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.object?["user"]?.object?["name"]?.string == "John")
        #expect(profile.object?["user"]?.object?["age"]?.int == 30)
    }

    @Test("Decode array of objects")
    func decodeArrayOfObjects() throws {
        let json = Data("[{\"id\":1},{\"id\":2}]".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.array?.count == 2)
        #expect(profile.array?[0].object?["id"]?.int == 1)
        #expect(profile.array?[1].object?["id"]?.int == 2)
    }

    @Test("Decode object with array values")
    func decodeObjectWithArrayValues() throws {
        let json = Data("{\"numbers\":[1,2,3]}".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.object?["numbers"]?.array?.count == 3)
        #expect(profile.object?["numbers"]?.array?[0].int == 1)
        #expect(profile.object?["numbers"]?.array?[2].int == 3)
    }

    @Test("Decode complex nested structure")
    func decodeComplexNested() throws {
        let json = Data("""
        {
            "user": {
                "name": "John",
                "contacts": [
                    {"type": "email", "value": "john@example.com"},
                    {"type": "phone", "value": "555-1234"}
                ],
                "active": true,
                "score": 95.5
            }
        }
        """.utf8)

        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)

        #expect(profile.object?["user"]?.object?["name"]?.string == "John")
        #expect(profile.object?["user"]?.object?["active"]?.bool == true)
        #expect(profile.object?["user"]?.object?["score"]?.double == 95.5)
        #expect(profile.object?["user"]?.object?["contacts"]?.array?.count == 2)
        #expect(profile.object?["user"]?.object?["contacts"]?.array?[0].object?["type"]?.string == "email")
        #expect(profile.object?["user"]?.object?["contacts"]?.array?[0].object?["value"]?.string == "john@example.com")
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip encoding and decoding for integer")
    func roundTripInteger() throws {
        let original = CodableProfile.integer(42)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: encoded)
        #expect(decoded.int == original.int)
    }

    @Test("Round-trip encoding and decoding for double")
    func roundTripDouble() throws {
        let original = CodableProfile.double(42.5)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: encoded)
        #expect(decoded.double == original.double)
    }

    @Test("Round-trip encoding and decoding for string")
    func roundTripString() throws {
        let original = CodableProfile.string("test")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: encoded)
        #expect(decoded.string == original.string)
    }

    @Test("Round-trip encoding and decoding for boolean")
    func roundTripBoolean() throws {
        let original = CodableProfile.boolean(true)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: encoded)
        #expect(decoded.bool == original.bool)
    }

    @Test("Round-trip encoding and decoding for null")
    func roundTripNull() throws {
        let original = CodableProfile.null
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: encoded)
        #expect(decoded.isNil == true)
    }

    @Test("Round-trip encoding and decoding for array")
    func roundTripArray() throws {
        let original = CodableProfile.array([.string("a"), .integer(1)])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: encoded)
        #expect(decoded.array?.count == 2)
        #expect(decoded.array?[0].string == "a")
        #expect(decoded.array?[1].int == 1)
    }

    @Test("Round-trip encoding and decoding for object")
    func roundTripObject() throws {
        let original = CodableProfile.object(["name": .string("John"), "age": .integer(30)])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: encoded)
        #expect(decoded.object?["name"]?.string == "John")
        #expect(decoded.object?["age"]?.int == 30)
    }
}
