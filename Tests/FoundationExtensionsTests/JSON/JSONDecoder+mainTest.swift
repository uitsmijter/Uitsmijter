import Foundation
@testable import FoundationExtensions
import Testing

@Suite("JSONDecoder Main Extension Tests", .serialized)
struct JSONDecoderMainTest {

    // Test data structures
    struct TestData: Codable {
        let name: String
        let age: Int
        let timestamp: Date
    }

    struct SimpleData: Codable {
        let value: String
    }

    @Test("Main decoder is accessible and functional")
    func mainDecoderExists() throws {
        let json = Data("""
        {
            "value": "test"
        }
        """.utf8)

        let decoded = try JSONDecoder.main.decode(SimpleData.self, from: json)
        #expect(decoded.value == "test")
    }

    @Test("Main decoder is a singleton instance")
    func mainDecoderIsSingleton() {
        let decoder1 = JSONDecoder.main
        let decoder2 = JSONDecoder.main

        // Both references should point to the same instance
        #expect(decoder1 === decoder2)
    }

    @Test("Configure main decoder with date decoding strategy")
    func configureDateDecodingStrategy() throws {
        // Configure for ISO8601
        JSONDecoder.configureMainDecoder { decoder in
            decoder.dateDecodingStrategy = .iso8601
        }

        let isoDateString = "2025-10-16T12:00:00Z"
        let json = Data("""
        {
            "name": "Test User",
            "age": 30,
            "timestamp": "\(isoDateString)"
        }
        """.utf8)

        let decoded = try JSONDecoder.main.decode(TestData.self, from: json)
        #expect(decoded.name == "Test User")
        #expect(decoded.age == 30)

        // Verify the date was decoded correctly with ISO8601 strategy
        let formatter = ISO8601DateFormatter()
        guard let expectedDate = formatter.date(from: isoDateString) else {
            Issue.record("Failed to parse ISO8601 date string")
            return
        }
        #expect(decoded.timestamp.timeIntervalSince1970 == expectedDate.timeIntervalSince1970)

        // Reset to default for other tests
        JSONDecoder.configureMainDecoder { decoder in
            decoder.dateDecodingStrategy = .deferredToDate
        }
    }

    @Test("Configure main decoder with key decoding strategy")
    func configureKeyDecodingStrategy() throws {
        struct SnakeCaseData: Codable {
            let firstName: String
            let lastName: String
        }

        JSONDecoder.configureMainDecoder { decoder in
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        }

        let json = Data("""
        {
            "first_name": "John",
            "last_name": "Doe"
        }
        """.utf8)

        let decoded = try JSONDecoder.main.decode(SnakeCaseData.self, from: json)
        #expect(decoded.firstName == "John")
        #expect(decoded.lastName == "Doe")

        // Reset to default for other tests
        JSONDecoder.configureMainDecoder { decoder in
            decoder.keyDecodingStrategy = .useDefaultKeys
        }
    }

    @Test("Configure main decoder persists across multiple decoding operations")
    func configurationPersists() throws {
        // Configure with a specific date strategy
        JSONDecoder.configureMainDecoder { decoder in
            decoder.dateDecodingStrategy = .secondsSince1970
        }

        let timestamp = Date().timeIntervalSince1970
        let json1 = Data("""
        {
            "name": "User1",
            "age": 25,
            "timestamp": \(timestamp)
        }
        """.utf8)

        let json2 = Data("""
        {
            "name": "User2",
            "age": 35,
            "timestamp": \(timestamp + 100)
        }
        """.utf8)

        // Decode multiple times - configuration should persist
        let decoded1 = try JSONDecoder.main.decode(TestData.self, from: json1)
        let decoded2 = try JSONDecoder.main.decode(TestData.self, from: json2)

        #expect(decoded1.name == "User1")
        #expect(decoded2.name == "User2")

        // Both should have valid timestamps decoded with the same strategy
        #expect(abs(decoded1.timestamp.timeIntervalSince1970 - timestamp) < 1.0)
        #expect(abs(decoded2.timestamp.timeIntervalSince1970 - (timestamp + 100)) < 1.0)

        // Reset to default
        JSONDecoder.configureMainDecoder { decoder in
            decoder.dateDecodingStrategy = .deferredToDate
        }
    }

    @Test("Main decoder can be configured multiple times")
    func multipleConfigurations() throws {
        struct Data1: Codable {
            let value: Int
        }

        // First configuration
        JSONDecoder.configureMainDecoder { decoder in
            decoder.keyDecodingStrategy = .useDefaultKeys
        }

        let json1 = Data("""
        {
            "value": 42
        }
        """.utf8)

        let result1 = try JSONDecoder.main.decode(Data1.self, from: json1)
        #expect(result1.value == 42)

        // Second configuration (overrides first)
        JSONDecoder.configureMainDecoder { decoder in
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        }

        // Should still work with new configuration
        let result2 = try JSONDecoder.main.decode(Data1.self, from: json1)
        #expect(result2.value == 42)
    }
}
