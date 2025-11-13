import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer
import Logger

@Suite("JavaScript Functions Logging Output Tests", .serialized)
@MainActor
struct JSFunctionsLoggingOutputTest {

    @Test("say function writes info message to log")
    func sayWritesInfoToLog() async throws {
        // Create isolated LogWriter for this test to prevent interference from parallel tests
        let testWriter = LogWriter(
            metadata: ["type": "test"],
            logLevel: .info,
            logFormat: .console
        )
        let jsp = JavaScriptProvider(logWriter: testWriter)
        _ = try await jsp.loadProvider(script: """
            function test() {
                say("Info level message from say");
                return "done";
            }
            test();
        """)

        // Check the log message using targeted search on the isolated writer
        let entry = try await testWriter.waitForLog(where: "Info level message from say")
        #expect(entry.message.contains("Info level message from say") == true)
        #expect(entry.level.contains("INFO") == true)
    }

    @Test("console.log writes info message to log")
    func consoleLogWritesInfoToLog() async throws {
        // Create isolated LogWriter for this test to prevent interference from parallel tests
        let testWriter = LogWriter(
            metadata: ["type": "test"],
            logLevel: .info,
            logFormat: .console
        )
        let jsp = JavaScriptProvider(logWriter: testWriter)
        _ = try await jsp.loadProvider(script: """
            function test() {
                console.log("Console log message");
                return "done";
            }
            test();
        """)

        // Check the log message using targeted search on the isolated writer
        let entry = try await testWriter.waitForLog(where: "Console log message")
        #expect(entry.message.contains("Console log message") == true)
        #expect(entry.level.contains("INFO") == true)
    }

    @Test("console.error writes error message to log")
    func consoleErrorWritesErrorToLog() async throws {
        // Create isolated LogWriter for this test to prevent interference from parallel tests
        let testWriter = LogWriter(
            metadata: ["type": "test"],
            logLevel: .info,
            logFormat: .console
        )
        let jsp = JavaScriptProvider(logWriter: testWriter)
        _ = try await jsp.loadProvider(script: """
            function test() {
                console.error("Error level message");
                return "done";
            }
            test();
        """)

        // Check the log message using targeted search on the isolated writer
        let entry = try await testWriter.waitForLog(where: "Error level message")
        #expect(entry.message.contains("Error level message") == true)
        #expect(entry.level.contains("ERROR") == true)
    }

    @Test("say function joins multiple arguments")
    func sayJoinsMultipleArgumentsInOutput() async throws {
        // Create isolated LogWriter for this test to prevent interference from parallel tests
        let testWriter = LogWriter(
            metadata: ["type": "test"],
            logLevel: .info,
            logFormat: .console
        )
        let jsp = JavaScriptProvider(logWriter: testWriter)
        _ = try await jsp.loadProvider(script: """
            function test() {
                say("Multiple", "arguments", "joined");
                return "done";
            }
            test();
        """)

        // Check that the message contains all the joined arguments on the isolated writer
        let entry = try await testWriter.waitForLog(where: "Multiple arguments joined")
        #expect(entry.message.contains("Multiple arguments joined") == true)
    }

    @Test("multiple log calls appear in log buffer")
    func multipleLogCallsAppear() async throws {
        // Create isolated LogWriter for this test to prevent interference from parallel tests
        let testWriter = LogWriter(
            metadata: ["type": "test"],
            logLevel: .info,
            logFormat: .console
        )
        let jsp = JavaScriptProvider(logWriter: testWriter)

        _ = try await jsp.loadProvider(script: """
            function test() {
                say("UniqueFirst123");
                console.log("UniqueSecond456");
                console.error("UniqueThird789");
                return "done";
            }
            test();
        """)

        // Verify all three messages are present using waitForLog on the isolated writer
        let firstEntry = try await testWriter.waitForLog(where: "UniqueFirst123")
        #expect(firstEntry.message.contains("UniqueFirst123"))

        let secondEntry = try await testWriter.waitForLog(where: "UniqueSecond456")
        #expect(secondEntry.message.contains("UniqueSecond456"))

        let thirdEntry = try await testWriter.waitForLog(where: "UniqueThird789")
        #expect(thirdEntry.message.contains("UniqueThird789"))
    }

    @Test("numeric arguments are converted to strings in output")
    func numericArgumentsConvertedToStrings() async throws {
        // Create isolated LogWriter for this test to prevent interference from parallel tests
        let testWriter = LogWriter(
            metadata: ["type": "test"],
            logLevel: .info,
            logFormat: .console
        )
        let jsp = JavaScriptProvider(logWriter: testWriter)
        _ = try await jsp.loadProvider(script: """
            function test() {
                say(42, 3.14, 100);
                return "done";
            }
            test();
        """)

        // Wait for the specific log entry on the isolated writer
        let entry = try await testWriter.waitForLog(where: "3.14")
        let message = entry.message
        #expect(message.contains("42"))
        #expect(message.contains("3.14"))
        #expect(message.contains("100"))
    }

    @Test("mixed type arguments appear in output")
    func mixedTypeArgumentsAppear() async throws {
        // Create isolated LogWriter for this test to prevent interference from parallel tests
        let testWriter = LogWriter(
            metadata: ["type": "test"],
            logLevel: .info,
            logFormat: .console
        )
        let jsp = JavaScriptProvider(logWriter: testWriter)
        _ = try await jsp.loadProvider(script: """
            function test() {
                say("String:", 42, true, false);
                return "done";
            }
            test();
        """)

        // Check that all types appear in the log message using targeted search on the isolated writer
        let entry = try await testWriter.waitForLog(where: "String:")
        let message = entry.message
        #expect(message.contains("String:"))
        #expect(message.contains("42"))
        #expect(message.contains("true"))
        #expect(message.contains("false"))
    }
}
