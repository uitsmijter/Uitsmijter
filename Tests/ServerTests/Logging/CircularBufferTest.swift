import Foundation
import XCTVapor
@testable import Server

final class CircularBufferTest: XCTestCase {
    func testPushElements() {
        var buf = CircularBuffer<String>(capacity: 5)
        XCTAssertEqual(buf.count, 0)

        buf.push("A")
        XCTAssertEqual(buf.count, 1)

        buf.push(["B", "C"])
        XCTAssertEqual(buf.count, 3)
    }

    func testPopElements() throws {
        var buf = CircularBuffer<String>(capacity: 5)
        buf.push(["A", "B", "C"])
        XCTAssertEqual(buf.count, 3)

        let testPop = buf.pop()
        XCTAssertEqual(testPop, "A")
        XCTAssertEqual(buf.count, 2)

        let testPops = buf.pop(amount: 2)
        XCTAssertEqual(testPops?.count, 2)
        guard let testPops else {
            throw TestError.abort
        }
        XCTAssertEqual(testPops[0], "B")
        XCTAssertEqual(testPops[1], "C")
        XCTAssertEqual(buf.count, 0)
    }

    func testOvercommittedPopElements() throws {
        var buf = CircularBuffer<String>(capacity: 5)
        buf.push(["A", "B", "C"])
        XCTAssertEqual(buf.count, 3)

        let testPops = buf.pop(amount: 5)
        XCTAssertEqual(testPops?.count, 3)
        guard let testPops else {
            throw TestError.abort
        }
        XCTAssertEqual(testPops[0], "A")
        XCTAssertEqual(testPops[1], "B")
        XCTAssertEqual(testPops[2], "C")
        XCTAssertEqual(buf.count, 0)
    }
}
