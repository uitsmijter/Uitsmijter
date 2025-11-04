import Foundation
import Logging
import Testing
@testable import Logger

@Suite("Logging Tests", .serialized)
@MainActor
struct LoggingTest {

    let writer = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
    let log: Logger

    init() {
        let logWriter = writer
        log = Logger(label: "test", factory: { _ in logWriter })
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
    func getLastLogEmptyBuffer() async {
        // Create a fresh writer with empty buffer
        let freshWriter = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
        let result = await freshWriter.getLastLog(where: "nonexistent")
        #expect(result == nil)
    }

    @Test("getLastLog finds single matching entry")
    func getLastLogSingleMatch() async {
        log.info("Unique test message 12345")
        let result = await writer.getLastLog(where: "Unique test message")
        #expect(result != nil)
        #expect(result?.message == "Unique test message 12345")
        #expect(result?.level == "INFO")
    }

    @Test("getLastLog returns most recent matching entry")
    func getLastLogMultipleMatches() async {
        log.info("Test message first occurrence")
        log.info("Some other message")
        log.info("Test message second occurrence")
        log.info("Yet another message")

        let result = await writer.getLastLog(where: "Test message")
        #expect(result != nil)
        #expect(result?.message == "Test message second occurrence")
    }

    @Test("getLastLog returns nil when no match found")
    func getLastLogNoMatch() async {
        log.info("Message A")
        log.info("Message B")
        log.info("Message C")

        let result = await writer.getLastLog(where: "nonexistent pattern")
        #expect(result == nil)
    }

    @Test("getLastLog is case sensitive")
    func getLastLogCaseSensitive() async {
        log.info("Case Sensitive Test")

        let resultUppercase = await writer.getLastLog(where: "Case Sensitive")
        #expect(resultUppercase != nil)

        let resultLowercase = await writer.getLastLog(where: "case sensitive")
        #expect(resultLowercase == nil)
    }

    @Test("getLastLog performs substring search")
    func getLastLogSubstringSearch() async {
        log.info("This is a complete message")

        let result = await writer.getLastLog(where: "complete")
        #expect(result != nil)
        #expect(result?.message == "This is a complete message")
    }

    @Test("getLastLog searches across different log levels")
    func getLastLogDifferentLevels() async {
        log.debug("Debug level search test")
        log.info("Info level search test")
        log.warning("Warning level search test")
        log.error("Error level search test")

        let debugResult = await writer.getLastLog(where: "Debug level")
        #expect(debugResult?.level == "DEBUG")

        let errorResult = await writer.getLastLog(where: "Error level")
        #expect(errorResult?.level == "ERROR")
    }

    @Test("getLastLog with full circular buffer")
    func getLastLogFullBuffer() async {
        // Create a writer with small buffer for testing
        let smallWriter = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
        let smallLog = Logger(label: "test-small", factory: { _ in smallWriter })

        // Fill buffer beyond capacity (250 entries)
        // Using unique messages to avoid substring matching issues
        for idx in 1...260 {
            smallLog.info("BufferTest message number: \(idx) END")
        }

        // Should find recent message (search for "number: 260 " with space after to avoid matching 2601, etc.)
        let recentResult = await smallWriter.getLastLog(where: "number: 260 ")
        #expect(recentResult != nil)

        // Should NOT find very old message (overwritten in circular buffer)
        // After 260 messages with capacity 250, first 10 messages (1-10) are overwritten
        // Search for "number: 1 " with space after to avoid matching 10, 100, 251, etc.
        let oldResult = await smallWriter.getLastLog(where: "number: 1 ")
        #expect(oldResult == nil)
    }

    @Test("getLastLog with special characters")
    func getLastLogSpecialCharacters() async {
        log.info("Message with special chars: @#$%^&*()")

        let result = await writer.getLastLog(where: "special chars")
        #expect(result != nil)
        #expect(result?.message.contains("@#$%^&*()") == true)
    }

    @Test("getLastLog preserves original buffer")
    func getLastLogNonDestructive() async {
        // Create a fresh writer to avoid interference from other tests
        let freshWriter = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
        let freshLog = Logger(label: "test-preservation", factory: { _ in freshWriter })

        // Log two messages to have something to search
        freshLog.info("First message for preservation test")
        freshLog.info("Second message for preservation test")

        // Wait briefly to ensure messages are fully processed by the actor
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Get the count before calling getLastLog
        let countBefore = await freshWriter.logBuffer.count
        #expect(countBefore == 2)

        // Call getLastLog - this should NOT modify the buffer
        _ = await freshWriter.getLastLog(where: "preservation test")

        // Get the count after calling getLastLog
        let countAfter = await freshWriter.logBuffer.count

        // Buffer count should remain the same (both should be 2)
        #expect(countBefore == countAfter)
    }
}
