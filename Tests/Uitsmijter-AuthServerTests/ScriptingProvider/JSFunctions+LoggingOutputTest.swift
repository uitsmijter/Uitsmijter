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
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            function test() {
                say("Info level message from say");
                return "done";
            }
            test();
        """)

        // Check the log message using targeted search
        let entry = Log.writer.getLastLog(where: "Info level message from say")
        #expect(entry != nil)
        #expect(entry?.message.contains("Info level message from say") == true)
        #expect(entry?.level.contains("INFO") == true)
    }

    @Test("console.log writes info message to log")
    func consoleLogWritesInfoToLog() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            function test() {
                console.log("Console log message");
                return "done";
            }
            test();
        """)

        // Check the log message using targeted search
        let entry = Log.writer.getLastLog(where: "Console log message")
        #expect(entry != nil)
        #expect(entry?.message.contains("Console log message") == true)
        #expect(entry?.level.contains("INFO") == true)
    }

    @Test("console.error writes error message to log")
    func consoleErrorWritesErrorToLog() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            function test() {
                console.error("Error level message");
                return "done";
            }
            test();
        """)

        // Check the log message using targeted search
        let entry = Log.writer.getLastLog(where: "Error level message")
        #expect(entry != nil)
        #expect(entry?.message.contains("Error level message") == true)
        #expect(entry?.level.contains("ERROR") == true)
    }

    @Test("say function joins multiple arguments")
    func sayJoinsMultipleArgumentsInOutput() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            function test() {
                say("Multiple", "arguments", "joined");
                return "done";
            }
            test();
        """)

        // Check that the message contains all the joined arguments
        let entry = Log.writer.getLastLog(where: "Multiple arguments joined")
        #expect(entry != nil)
        #expect(entry?.message.contains("Multiple arguments joined") == true)
    }

    @Test("multiple log calls appear in log buffer")
    func multipleLogCallsAppear() async throws {
        let jsp = JavaScriptProvider()

        // Get current buffer count to know where we start
        let initialCount = Log.writer.logBuffer.count

        _ = try await jsp.loadProvider(script: """
            function test() {
                say("UniqueFirst123");
                console.log("UniqueSecond456");
                console.error("UniqueThird789");
                return "done";
            }
            test();
        """)

        // Check that buffer has grown (we should have at least 3 new messages)
        let newCount = Log.writer.logBuffer.count
        #expect(newCount >= initialCount + 3)

        // Verify all three messages are present using targeted search
        let firstEntry = Log.writer.getLastLog(where: "UniqueFirst123")
        #expect(firstEntry != nil)

        let secondEntry = Log.writer.getLastLog(where: "UniqueSecond456")
        #expect(secondEntry != nil)

        let thirdEntry = Log.writer.getLastLog(where: "UniqueThird789")
        #expect(thirdEntry != nil)
    }

    @Test("numeric arguments are converted to strings in output")
    func numericArgumentsConvertedToStrings() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            function test() {
                say(42, 3.14, 100);
                return "done";
            }
            test();
        """)

        // Check that numbers appear in the log message using targeted search
        let entry = Log.writer.getLastLog(where: "42")
        #expect(entry != nil)
        let message = entry?.message ?? ""
        #expect(message.contains("42"))
        #expect(message.contains("3.14"))
        #expect(message.contains("100"))
    }

    @Test("mixed type arguments appear in output")
    func mixedTypeArgumentsAppear() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            function test() {
                say("String:", 42, true, false);
                return "done";
            }
            test();
        """)

        // Check that all types appear in the log message using targeted search
        let entry = Log.writer.getLastLog(where: "String:")
        #expect(entry != nil)
        let message = entry?.message ?? ""
        #expect(message.contains("String:"))
        #expect(message.contains("42"))
        #expect(message.contains("true"))
        #expect(message.contains("false"))
    }
}
