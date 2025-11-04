import Testing
@testable import Uitsmijter_AuthServer
import Foundation

/// Tests for CodableProfile basic functionality: enum cases, encoding, and decoding
@Suite("CodableProfile Basic Tests")
struct CodableProfileBasicTest {

    // MARK: - Enum Case Tests

    @Test("CodableProfile double case stores value")
    func doubleCase() throws {
        let profile = CodableProfile.double(42.5)
        #expect(profile.double == 42.5)
        #expect(profile.int == nil)
        #expect(profile.string == nil)
        #expect(profile.bool == nil)
        #expect(profile.array == nil)
        #expect(profile.object == nil)
        #expect(profile.isNil == false)
    }

    @Test("CodableProfile integer case stores value")
    func integerCase() throws {
        let profile = CodableProfile.integer(42)
        #expect(profile.int == 42)
        #expect(profile.double == nil)
        #expect(profile.string == nil)
        #expect(profile.bool == nil)
        #expect(profile.array == nil)
        #expect(profile.object == nil)
        #expect(profile.isNil == false)
    }

    @Test("CodableProfile string case stores value")
    func stringCase() throws {
        let profile = CodableProfile.string("test")
        #expect(profile.string == "test")
        #expect(profile.int == nil)
        #expect(profile.double == nil)
        #expect(profile.bool == nil)
        #expect(profile.array == nil)
        #expect(profile.object == nil)
        #expect(profile.isNil == false)
    }

    @Test("CodableProfile boolean case stores value")
    func booleanCase() throws {
        let profile = CodableProfile.boolean(true)
        #expect(profile.bool == true)
        #expect(profile.int == nil)
        #expect(profile.double == nil)
        #expect(profile.string == nil)
        #expect(profile.array == nil)
        #expect(profile.object == nil)
        #expect(profile.isNil == false)
    }

    @Test("CodableProfile null case")
    func nullCase() throws {
        let profile = CodableProfile.null
        #expect(profile.isNil == true)
        #expect(profile.int == nil)
        #expect(profile.double == nil)
        #expect(profile.string == nil)
        #expect(profile.bool == nil)
        #expect(profile.array == nil)
        #expect(profile.object == nil)
    }

    @Test("CodableProfile array case stores values")
    func arrayCase() throws {
        let profile = CodableProfile.array([.string("a"), .integer(1), .boolean(true)])
        #expect(profile.array?.count == 3)
        #expect(profile.array?[0].string == "a")
        #expect(profile.array?[1].int == 1)
        #expect(profile.array?[2].bool == true)
        #expect(profile.int == nil)
        #expect(profile.string == nil)
        #expect(profile.object == nil)
        #expect(profile.isNil == false)
    }

    @Test("CodableProfile object case stores key-value pairs")
    func objectCase() throws {
        let profile = CodableProfile.object([
            "name": .string("John"),
            "age": .integer(30),
            "active": .boolean(true)
        ])
        #expect(profile.object?["name"]?.string == "John")
        #expect(profile.object?["age"]?.int == 30)
        #expect(profile.object?["active"]?.bool == true)
        #expect(profile.int == nil)
        #expect(profile.string == nil)
        #expect(profile.array == nil)
        #expect(profile.isNil == false)
    }

    // MARK: - Encoding Tests

    @Test("Encode double to JSON")
    func encodeDouble() throws {
        let profile = CodableProfile.double(42.5)
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "42.5")
    }

    @Test("Encode integer to JSON")
    func encodeInteger() throws {
        let profile = CodableProfile.integer(42)
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "42")
    }

    @Test("Encode string to JSON")
    func encodeString() throws {
        let profile = CodableProfile.string("test")
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "\"test\"")
    }

    @Test("Encode boolean true to JSON")
    func encodeBooleanTrue() throws {
        let profile = CodableProfile.boolean(true)
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "true")
    }

    @Test("Encode boolean false to JSON")
    func encodeBooleanFalse() throws {
        let profile = CodableProfile.boolean(false)
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "false")
    }

    @Test("Encode null to JSON")
    func encodeNull() throws {
        let profile = CodableProfile.null
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "null")
    }

    @Test("Encode array to JSON")
    func encodeArray() throws {
        let profile = CodableProfile.array([.string("a"), .integer(1)])
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "[\"a\",1]")
    }

    @Test("Encode object to JSON")
    func encodeObject() throws {
        let profile = CodableProfile.object(["name": .string("John")])
        let encoded = try JSONEncoder().encode(profile)
        let json = String(data: encoded, encoding: .utf8)
        #expect(json == "{\"name\":\"John\"}")
    }

    // MARK: - Decoding Tests

    @Test("Decode integer from JSON")
    func decodeInteger() throws {
        let json = Data("42".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.int == 42)
    }

    @Test("Decode double from JSON")
    func decodeDouble() throws {
        let json = Data("42.5".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.double == 42.5)
    }

    @Test("Decode string from JSON")
    func decodeString() throws {
        let json = Data("\"test\"".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.string == "test")
    }

    @Test("Decode boolean true from JSON")
    func decodeBooleanTrue() throws {
        let json = Data("true".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.bool == true)
    }

    @Test("Decode boolean false from JSON")
    func decodeBooleanFalse() throws {
        let json = Data("false".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.bool == false)
    }

    @Test("Decode null from JSON")
    func decodeNull() throws {
        let json = Data("null".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.isNil == true)
    }

    @Test("Decode array from JSON")
    func decodeArray() throws {
        let json = Data("[\"a\",1,true]".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.array?.count == 3)
        #expect(profile.array?[0].string == "a")
        #expect(profile.array?[1].int == 1)
        #expect(profile.array?[2].bool == true)
    }

    @Test("Decode object from JSON")
    func decodeObject() throws {
        let json = Data("{\"name\":\"John\",\"age\":30}".utf8)
        let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
        #expect(profile.object?["name"]?.string == "John")
        #expect(profile.object?["age"]?.int == 30)
    }
}
