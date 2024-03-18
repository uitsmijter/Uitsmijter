import Foundation
@testable import Server
import XCTVapor

final class LoggingDebugFunctionsTest: XCTestCase {

    override func setUp() {
        Log.main = Log(level: Logger.Level.trace)
    }

    func testDebugLogFromThisFunction() {
        Log.debug("Test log entry")
        XCTAssertContains(LogWriter.lastLog?.message, "log")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "debug")
        XCTAssertEqual("testDebugLogFromThisFunction()", #function)

        XCTAssertContains(LogWriter.lastLog?.function, #function)
    }

    func testInfoLogFromThisFunction() {
        Log.info("Test log entry")
        XCTAssertContains(LogWriter.lastLog?.message, "log")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "info")
        XCTAssertEqual("testInfoLogFromThisFunction()", #function)

        XCTAssertContains(LogWriter.lastLog?.function, #function)
    }

    func testNoticeLogFromThisFunction() {
        Log.notice("Test log entry")
        XCTAssertContains(LogWriter.lastLog?.message, "log")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "notice")
        XCTAssertEqual("testNoticeLogFromThisFunction()", #function)

        XCTAssertContains(LogWriter.lastLog?.function, #function)
    }

    func testWarningLogFromThisFunction() {
        Log.warning("Test log entry")
        XCTAssertContains(LogWriter.lastLog?.message, "log")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "warning")
        XCTAssertEqual("testWarningLogFromThisFunction()", #function)

        XCTAssertContains(LogWriter.lastLog?.function, #function)
    }

    func testErrorLogFromThisFunction() {
        Log.error("Test log entry")
        XCTAssertContains(LogWriter.lastLog?.message, "log")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "error")
        XCTAssertEqual("testErrorLogFromThisFunction()", #function)

        XCTAssertContains(LogWriter.lastLog?.function, #function)
    }

    func testCriticalLogFromThisFunction() {
        Log.critical("Test log entry")
        XCTAssertContains(LogWriter.lastLog?.message, "log")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "critical")
        XCTAssertEqual("testCriticalLogFromThisFunction()", #function)

        XCTAssertContains(LogWriter.lastLog?.function, #function)
    }
}
