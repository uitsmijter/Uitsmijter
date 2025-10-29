import Foundation
import Logging
import Testing
@testable import Logger

@Suite("NDJSON Logging Tests", .serialized)
@MainActor
struct LoggingNDJSONTest {

    /// Test that NDJSON format produces valid JSON output
    @Test("NDJSON format produces valid JSON")
    func ndjsonFormat() throws {
        // Create a LogWriter with NDJSON format
        let writer = LogWriter(
            metadata: ["service": "test"],
            logLevel: .info,
            logFormat: .ndjson
        )

        // Log a test message and capture it
        writer.log(
            level: .info,
            message: "Test NDJSON message",
            metadata: ["test_key": "test_value"],
            source: "TestSource",
            file: #fileID,
            function: #function,
            line: #line
        )

        // Verify the message was captured
        guard let lastLog = LogWriter.lastLog else {
            throw TestError.noLogCaptured
        }

        #expect(lastLog.message == "Test NDJSON message")
        #expect(lastLog.level.uppercased() == "INFO")
        #expect(lastLog.metadata?["test_key"] == "test_value")
        #expect(lastLog.metadata?["service"] == "test")

        // Verify the message can be encoded to JSON (NDJSON format requirement)
        let jsonData = try JSONEncoder().encode(lastLog)
        #expect(!jsonData.isEmpty)

        // Verify it's valid JSON by parsing it
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        #expect(json?["message"] as? String == "Test NDJSON message")
        #expect(json?["level"] as? String == "INFO")
    }

    /// Test that NDJSON format includes all required fields
    @Test("NDJSON includes all required fields")
    func ndjsonRequiredFields() throws {
        let writer = LogWriter(
            metadata: [:],
            logLevel: .warning,
            logFormat: .ndjson
        )

        writer.log(
            level: .warning,
            message: "Warning message",
            metadata: nil,
            source: "TestModule",
            file: #fileID,
            function: #function,
            line: #line
        )

        guard let lastLog = LogWriter.lastLog else {
            throw TestError.noLogCaptured
        }

        // Required fields for NDJSON
        #expect(lastLog.level.isEmpty == false)
        #expect(lastLog.message.isEmpty == false)
        #expect(lastLog.source?.isEmpty == false)

        // Encode to JSON and verify structure
        let jsonData = try JSONEncoder().encode(lastLog)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        #expect(json != nil)
        #expect(json?["level"] as? String == "WARNING")
        #expect(json?["message"] as? String == "Warning message")
        #expect(json?["source"] as? String == "TestModule")
        #expect(json?["date"] != nil)
    }

    /// Test that NDJSON format handles metadata correctly
    @Test("NDJSON handles metadata correctly")
    func ndjsonMetadata() throws {
        let writer = LogWriter(
            metadata: ["global_key": "global_value"],
            logLevel: .error,
            logFormat: .ndjson
        )

        writer.log(
            level: .error,
            message: "Error with metadata",
            metadata: [
                "error_code": "500",
                "component": "database"
            ],
            source: "ErrorHandler",
            file: #fileID,
            function: #function,
            line: #line
        )

        guard let lastLog = LogWriter.lastLog else {
            throw TestError.noLogCaptured
        }

        // Verify metadata merged correctly
        #expect(lastLog.metadata?["error_code"] == "500")
        #expect(lastLog.metadata?["component"] == "database")
        #expect(lastLog.metadata?["global_key"] == "global_value")

        // Encode and verify JSON structure
        let jsonData = try JSONEncoder().encode(lastLog)
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        let metadata = json?["metadata"] as? [String: String]

        #expect(metadata?["error_code"] == "500")
        #expect(metadata?["component"] == "database")
        #expect(metadata?["global_key"] == "global_value")
    }

    /// Test that NDJSON format handles special characters
    @Test("NDJSON handles special characters")
    func ndjsonSpecialCharacters() throws {
        let writer = LogWriter(
            metadata: [:],
            logLevel: .info,
            logFormat: .ndjson
        )

        let messageWithSpecialChars = "Message with \"quotes\" and newlines\nand tabs\t"

        writer.log(
            level: .info,
            message: Logger.Message(stringLiteral: messageWithSpecialChars),
            metadata: ["key": "value with \"quotes\""],
            source: "Test",
            file: #fileID,
            function: #function,
            line: #line
        )

        guard let lastLog = LogWriter.lastLog else {
            throw TestError.noLogCaptured
        }

        // Verify message was captured with special characters
        #expect(lastLog.message.contains("\"quotes\""))

        // Verify it can still be encoded to valid JSON
        let jsonData = try JSONEncoder().encode(lastLog)
        #expect(!jsonData.isEmpty)

        // Verify JSON is valid by parsing it
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        #expect(json != nil)
        let message = json?["message"] as? String
        #expect(message?.contains("quotes") == true)
    }

    /// Test error for missing log
    enum TestError: Error {
        case noLogCaptured
    }
}
