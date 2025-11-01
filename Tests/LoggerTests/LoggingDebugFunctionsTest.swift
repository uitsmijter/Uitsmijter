import Foundation
import Logging
import Testing
@testable import Logger

@Suite("Logging Debug Functions Tests", .serialized)
@MainActor
struct LoggingDebugFunctionsTest {

    let writer = LogWriter(metadata: ["type": "test"], logLevel: .debug, logFormat: .console)
    let log: Logger

    init() {
        let w = writer
        log = Logger(label: "test", factory: { _ in w })
    }
    
    
    @Test("Debug log captures function name")
    func debugLogFromThisFunction() {
        log.debug("Test log entry")

        // Debug logs are only captured if LOG_LEVEL is set to debug or trace
        // If the log was captured (not filtered), verify it
        if let lastLog = writer.lastLog, lastLog.level.lowercased() == "debug" {
            #expect(lastLog.message.contains("log") == true)
            #expect("debugLogFromThisFunction()" == #function)
            #expect(lastLog.function?.contains(#function) == true)
        }
    }

    @Test("Info log captures function name")
    func infoLogFromThisFunction() {
        log.info("Test log entry")
        #expect(writer.lastLog?.message.contains("log") == true)
        #expect(writer.lastLog?.level.lowercased() == "info")
        #expect("infoLogFromThisFunction()" == #function)

        #expect(writer.lastLog?.function?.contains(#function) == true)
    }

    @Test("Notice log captures function name")
    func noticeLogFromThisFunction() {
        log.notice("Test log entry")
        #expect(writer.lastLog?.message.contains("log") == true)
        #expect(writer.lastLog?.level.lowercased() == "notice")
        #expect("noticeLogFromThisFunction()" == #function)

        #expect(writer.lastLog?.function?.contains(#function) == true)
    }

    @Test("Warning log captures function name")
    func warningLogFromThisFunction() {
        log.warning("Test log entry")
        #expect(writer.lastLog?.message.contains("log") == true)
        #expect(writer.lastLog?.level.lowercased() == "warning")
        #expect("warningLogFromThisFunction()" == #function)

        #expect(writer.lastLog?.function?.contains(#function) == true)
    }

    @Test("Error log captures function name")
    func errorLogFromThisFunction() {
        log.error("Test log entry")
        #expect(writer.lastLog?.message.contains("log") == true)
        #expect(writer.lastLog?.level.lowercased() == "error")
        #expect("errorLogFromThisFunction()" == #function)

        #expect(writer.lastLog?.function?.contains(#function) == true)
    }

    @Test("Critical log captures function name")
    func criticalLogFromThisFunction() {
        log.critical("Test log entry")
        #expect(writer.lastLog?.message.contains("log") == true)
        #expect(writer.lastLog?.level.lowercased() == "critical")
        #expect("criticalLogFromThisFunction()" == #function)

        #expect(writer.lastLog?.function?.contains(#function) == true)
    }
}
