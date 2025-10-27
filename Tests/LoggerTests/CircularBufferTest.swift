import Foundation
import Testing
@testable import Logger

enum TestError: Error {
    case abort
    case fail(withError: String)
}

@Suite("Circular Buffer Tests")
@MainActor
struct CircularBufferTest {
    @Test("Push elements to circular buffer")
    func pushElements() {
        var buf = CircularBuffer<String>(capacity: 5)
        #expect(buf.isEmpty)

        buf.push("A")
        #expect(buf.count == 1)

        buf.push(["B", "C"])
        #expect(buf.count == 3)
    }

    @Test("Pop elements from circular buffer")
    func popElements() throws {
        var buf = CircularBuffer<String>(capacity: 5)
        buf.push(["A", "B", "C"])
        #expect(buf.count == 3)

        let testPop = buf.pop()
        #expect(testPop == "A")
        #expect(buf.count == 2)

        let testPops = buf.pop(amount: 2)
        #expect(testPops?.count == 2)
        guard let testPops else {
            throw TestError.abort
        }
        #expect(testPops[0] == "B")
        #expect(testPops[1] == "C")
        #expect(buf.isEmpty)
    }

    @Test("Pop more elements than available")
    func overcommittedPopElements() throws {
        var buf = CircularBuffer<String>(capacity: 5)
        buf.push(["A", "B", "C"])
        #expect(buf.count == 3)

        let testPops = buf.pop(amount: 5)
        #expect(testPops?.count == 3)
        guard let testPops else {
            throw TestError.abort
        }
        #expect(testPops[0] == "A")
        #expect(testPops[1] == "B")
        #expect(testPops[2] == "C")
        #expect(buf.isEmpty)
    }
}
