import Foundation
import Logging
import Testing
@testable import Logger

@Suite("Logging Tests", .serialized)
@MainActor
struct LoggingTest {

    let writer = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
    let log: Logger
    
    init() async throws {
        log = Log.getPrivateLogger(label: "test", writer: writer)
    }
    
    @Test("Log with basic logger")
    func logFoo() {
        let log = Log.shared
        log.info("Hello")
    }

    @Test("Log handler notice level")
    func logHandlerNotice() {
        log.notice("Hello Notice")
        #expect(writer.lastLog?.message == "Hello Notice")
        #expect(writer.lastLog?.level.lowercased() == "notice")
    }

    @Test("Log handler info level")
    func logHandlerInfo() {
        log.info("Hello Info")
        #expect(writer.lastLog?.message == "Hello Info")
        #expect(writer.lastLog?.level.lowercased() == "info")
    }

    @Test("Log handler error level")
    func logHandlerError() {
        log.error("Hello Error")
        #expect(writer.lastLog?.message == "Hello Error")
        #expect(writer.lastLog?.level.lowercased() == "error")
    }

    // MARK: - getLastLog(where:) Tests

    @Test("getLastLog returns nil for empty buffer")
    func getLastLogEmptyBuffer() {
        // Create a fresh writer with empty buffer
        let freshWriter = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
        let result = freshWriter.getLastLog(where: "nonexistent")
        #expect(result == nil)
    }

    @Test("getLastLog finds single matching entry")
    func getLastLogSingleMatch() {
        log.info("Unique test message 12345")
        let result = writer.getLastLog(where: "Unique test message")
        #expect(result != nil)
        #expect(result?.message == "Unique test message 12345")
        #expect(result?.level == "INFO")
    }

    @Test("getLastLog returns most recent matching entry")
    func getLastLogMultipleMatches() {
        log.info("Test message first occurrence")
        log.info("Some other message")
        log.info("Test message second occurrence")
        log.info("Yet another message")

        let result = writer.getLastLog(where: "Test message")
        #expect(result != nil)
        #expect(result?.message == "Test message second occurrence")
    }

    @Test("getLastLog returns nil when no match found")
    func getLastLogNoMatch() {
        log.info("Message A")
        log.info("Message B")
        log.info("Message C")

        let result = writer.getLastLog(where: "nonexistent pattern")
        #expect(result == nil)
    }

    @Test("getLastLog is case sensitive")
    func getLastLogCaseSensitive() {
        log.info("Case Sensitive Test")

        let resultUppercase = writer.getLastLog(where: "Case Sensitive")
        #expect(resultUppercase != nil)

        let resultLowercase = writer.getLastLog(where: "case sensitive")
        #expect(resultLowercase == nil)
    }

    @Test("getLastLog performs substring search")
    func getLastLogSubstringSearch() {
        log.info("This is a complete message")

        let result = writer.getLastLog(where: "complete")
        #expect(result != nil)
        #expect(result?.message == "This is a complete message")
    }

    @Test("getLastLog searches across different log levels")
    func getLastLogDifferentLevels() {
        log.debug("Debug level search test")
        log.info("Info level search test")
        log.warning("Warning level search test")
        log.error("Error level search test")

        let debugResult = writer.getLastLog(where: "Debug level")
        #expect(debugResult?.level == "DEBUG")

        let errorResult = writer.getLastLog(where: "Error level")
        #expect(errorResult?.level == "ERROR")
    }

    @Test("getLastLog with full circular buffer")
    func getLastLogFullBuffer() async {
        // Create a writer with small buffer for testing
        let smallWriter = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
        let smallLog = Log.getPrivateLogger(label: "test-small", writer: smallWriter)

        // Fill buffer beyond capacity (250 entries)
        for idx in 1...260 {
            smallLog.info("Message number \(idx)")
        }

        // Should find recent message
        let recentResult = smallWriter.getLastLog(where: "Message number 260")
        #expect(recentResult != nil)

        // Should NOT find very old message (overwritten in circular buffer)
        let oldResult = smallWriter.getLastLog(where: "Message number 1")
        #expect(oldResult == nil)
    }

    @Test("getLastLog with special characters")
    func getLastLogSpecialCharacters() {
        log.info("Message with special chars: @#$%^&*()")

        let result = writer.getLastLog(where: "special chars")
        #expect(result != nil)
        #expect(result?.message.contains("@#$%^&*()") == true)
    }

    @Test("getLastLog preserves original buffer")
    func getLastLogNonDestructive() {
        log.info("First message for preservation test")
        log.info("Second message for preservation test")

        let countBefore = writer.logBuffer.count
        _ = writer.getLastLog(where: "preservation test")
        let countAfter = writer.logBuffer.count

        // Buffer count should remain the same
        #expect(countBefore == countAfter)
    }
}
