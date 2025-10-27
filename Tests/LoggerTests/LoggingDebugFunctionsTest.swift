import Foundation
import Logging
import Testing
@testable import Logger

@Suite("Logging Debug Functions Tests")
@MainActor
struct LoggingDebugFunctionsTest {

    @Test("Debug log captures function name")
    func debugLogFromThisFunction() {
        Log.debug("Test log entry")

        // Debug logs are only captured if LOG_LEVEL is set to debug or trace
        // If the log was captured (not filtered), verify it
        if let lastLog = LogWriter.lastLog, lastLog.level.lowercased() == "debug" {
            #expect(lastLog.message.contains("log") == true)
            #expect("debugLogFromThisFunction()" == #function)
            #expect(lastLog.function?.contains(#function) == true)
        }
    }

    @Test("Info log captures function name")
    func infoLogFromThisFunction() {
        Log.info("Test log entry")
        #expect(LogWriter.lastLog?.message.contains("log") == true)
        #expect(LogWriter.lastLog?.level.lowercased() == "info")
        #expect("infoLogFromThisFunction()" == #function)

        #expect(LogWriter.lastLog?.function?.contains(#function) == true)
    }

    @Test("Notice log captures function name")
    func noticeLogFromThisFunction() {
        Log.notice("Test log entry")
        #expect(LogWriter.lastLog?.message.contains("log") == true)
        #expect(LogWriter.lastLog?.level.lowercased() == "notice")
        #expect("noticeLogFromThisFunction()" == #function)

        #expect(LogWriter.lastLog?.function?.contains(#function) == true)
    }

    @Test("Warning log captures function name")
    func warningLogFromThisFunction() {
        Log.warning("Test log entry")
        #expect(LogWriter.lastLog?.message.contains("log") == true)
        #expect(LogWriter.lastLog?.level.lowercased() == "warning")
        #expect("warningLogFromThisFunction()" == #function)

        #expect(LogWriter.lastLog?.function?.contains(#function) == true)
    }

    @Test("Error log captures function name")
    func errorLogFromThisFunction() {
        Log.error("Test log entry")
        #expect(LogWriter.lastLog?.message.contains("log") == true)
        #expect(LogWriter.lastLog?.level.lowercased() == "error")
        #expect("errorLogFromThisFunction()" == #function)

        #expect(LogWriter.lastLog?.function?.contains(#function) == true)
    }

    @Test("Critical log captures function name")
    func criticalLogFromThisFunction() {
        Log.critical("Test log entry")
        #expect(LogWriter.lastLog?.message.contains("log") == true)
        #expect(LogWriter.lastLog?.level.lowercased() == "critical")
        #expect("criticalLogFromThisFunction()" == #function)

        #expect(LogWriter.lastLog?.function?.contains(#function) == true)
    }
}
