import Foundation
@testable import Server
import XCTVapor

final class LoggingTest: XCTestCase {

    override func setUp() {
        Log.main = Log(level: Logger.Level.trace)
    }

    func testLogFoo() {
        let log = Log.main.getLogger()
        log.info("Hello")
    }

    func testLogHandlerNotice() {
        Log.notice("Hello Notice")
        XCTAssertEqual(LogWriter.lastLog?.message, "Hello Notice")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "notice")
    }

    func testLogHandlerInfo() {
        Log.info("Hello Info")
        XCTAssertEqual(LogWriter.lastLog?.message, "Hello Info")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "info")
    }

    func testLogHandlerNotInfo() {
        Log.main = Log(level: Logger.Level.error)
        Log.info("Hello Info Again")
        XCTAssertNotEqual(LogWriter.lastLog?.message, "Hello Info Again")
    }

    func testLogHandlerError() {
        Log.error("Hello Error")
        XCTAssertEqual(LogWriter.lastLog?.message, "Hello Error")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "error")
    }
}
