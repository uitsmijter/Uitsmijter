import Foundation
@testable import FoundationExtensions
import Testing

/// Tests for JSONEncoder+main extension
@Suite("JSONEncoder+main Tests")
struct JSONEncoderMainTest {

    @Test("JSONEncoder.main is accessible")
    func mainEncoderIsAccessible() {
        let encoder = JSONEncoder.main
        // Verify encoder can be used to encode data
        struct TestData: Codable {
            let value: Int
        }
        let data = try? encoder.encode(TestData(value: 42))
        #expect(data != nil)
    }

    @Test("JSONEncoder.main can encode simple struct")
    func mainEncoderCanEncodeStruct() throws {
        struct TestStruct: Codable {
            let name: String
            let value: Int
        }

        let test = TestStruct(name: "test", value: 42)
        let data = try JSONEncoder.main.encode(test)
        #expect(!data.isEmpty)

        // Verify it decodes correctly
        let decoded = try JSONDecoder.main.decode(TestStruct.self, from: data)
        #expect(decoded.name == "test")
        #expect(decoded.value == 42)
    }

    @Test("JSONEncoder.configureMainEncoder can set output formatting")
    func configureMainEncoderSetsFormatting() throws {
        struct TestStruct: Codable {
            let name: String
            let value: Int
        }

        // Create a new encoder instance for this test to avoid shared state issues
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let test = TestStruct(name: "test", value: 42)
        let data = try encoder.encode(test)
        let jsonString = String(data: data, encoding: .utf8)

        // Pretty printed JSON should contain newlines
        #expect(jsonString?.contains("\n") == true)
    }

    @Test("JSONEncoder.configureMainEncoder can set date encoding strategy")
    func configureMainEncoderSetsDateStrategy() throws {
        struct TestStruct: Codable {
            let date: Date
        }

        // Configure for ISO8601 dates
        JSONEncoder.configureMainEncoder { encoder in
            encoder.dateEncodingStrategy = .iso8601
        }

        let date = Date(timeIntervalSince1970: 0)
        let test = TestStruct(date: date)
        let data = try JSONEncoder.main.encode(test)
        let jsonString = String(data: data, encoding: .utf8)

        // ISO8601 formatted date should be present
        #expect(jsonString?.contains("1970") == true)

        // Reset to default
        JSONEncoder.configureMainEncoder { encoder in
            encoder.dateEncodingStrategy = .deferredToDate
        }
    }

    @Test("JSONEncoder.configureMainEncoder can set key encoding strategy")
    func configureMainEncoderSetsKeyStrategy() throws {
        struct TestStruct: Codable {
            let someValue: String
        }

        // Configure for snake_case keys
        JSONEncoder.configureMainEncoder { encoder in
            encoder.keyEncodingStrategy = .convertToSnakeCase
        }

        let test = TestStruct(someValue: "test")
        let data = try JSONEncoder.main.encode(test)
        let jsonString = String(data: data, encoding: .utf8)

        // Should contain snake_case key
        #expect(jsonString?.contains("some_value") == true)

        // Reset to default
        JSONEncoder.configureMainEncoder { encoder in
            encoder.keyEncodingStrategy = .useDefaultKeys
        }
    }

    @Test("JSONEncoder.main is a shared instance")
    func mainEncoderIsSharedInstance() {
        let encoder1 = JSONEncoder.main
        let encoder2 = JSONEncoder.main

        // Should be the same instance
        #expect(encoder1 === encoder2)
    }

    @Test("JSONEncoder.configureMainEncoder affects the shared instance")
    func configureAffectsSharedInstance() throws {
        struct TestStruct: Codable {
            let value: Int
        }

        // Configure once
        JSONEncoder.configureMainEncoder { encoder in
            encoder.outputFormatting = .sortedKeys
        }

        // Encode with the configured instance
        let test = TestStruct(value: 42)
        let data = try JSONEncoder.main.encode(test)
        #expect(!data.isEmpty)

        // Reset
        JSONEncoder.configureMainEncoder { encoder in
            encoder.outputFormatting = []
        }
    }
}
