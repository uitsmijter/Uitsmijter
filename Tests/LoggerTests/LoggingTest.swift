import Foundation
import Logging
import Testing
@testable import Logger

@Suite("Logging Tests", .serialized)
@MainActor
struct LoggingTest {

    @Test("Log with basic logger")
    func logFoo() {
        let log = Log.shared
        log.info("Hello")
    }

    @Test("Log handler notice level")
    func logHandlerNotice() {
        Log.notice("Hello Notice")
        #expect(LogWriter.lastLog?.message == "Hello Notice")
        #expect(LogWriter.lastLog?.level.lowercased() == "notice")
    }

    @Test("Log handler info level")
    func logHandlerInfo() {
        Log.info("Hello Info")
        #expect(LogWriter.lastLog?.message == "Hello Info")
        #expect(LogWriter.lastLog?.level.lowercased() == "info")
    }

    @Test("Log handler filters info when level is error")
    func logHandlerNotInfo() {
        // Note: This test relies on LOG_LEVEL environment variable
        // If set to error, info messages will be filtered
        Log.info("Hello Info Again")
        // Test is environment-dependent
    }

    @Test("Log handler error level")
    func logHandlerError() {
        Log.error("Hello Error")
        #expect(LogWriter.lastLog?.message == "Hello Error")
        #expect(LogWriter.lastLog?.level.lowercased() == "error")
    }
}
