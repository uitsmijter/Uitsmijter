import Foundation
@testable import Server
import XCTVapor

final class LoggingDebugFunctionsTest: XCTestCase {

    override func setUp() {
        Log.main = Log(level: Logger.Level.trace)
    }

    func testLogFromThisFunction() {
        Log.debug("Log from testLogFromThisFunction")
        XCTAssertEqual(LogWriter.lastLog?.message, "Log from testLogFromThisFunction")
        XCTAssertEqual(LogWriter.lastLog?.level.lowercased(), "debug")
        XCTAssertContains(LogWriter.lastLog?.function, #function)
    }
}
