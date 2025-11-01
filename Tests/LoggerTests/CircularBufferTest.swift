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
    func pushElements() async {
        let buf = CircularBuffer<String>(capacity: 5)
        let isEmpty = await buf.isEmpty
        #expect(isEmpty)

        await buf.push("A")
        let count1 = await buf.count
        #expect(count1 == 1)

        await buf.push(["B", "C"])
        let count2 = await buf.count
        #expect(count2 == 3)
    }

    @Test("Pop elements from circular buffer")
    func popElements() async throws {
        let buf = CircularBuffer<String>(capacity: 5)
        await buf.push(["A", "B", "C"])
        let count1 = await buf.count
        #expect(count1 == 3)

        let testPop = await buf.pop()
        #expect(testPop == "A")
        let count2 = await buf.count
        #expect(count2 == 2)

        let testPops = await buf.pop(amount: 2)
        #expect(testPops?.count == 2)
        guard let testPops else {
            throw TestError.abort
        }
        #expect(testPops[0] == "B")
        #expect(testPops[1] == "C")
        let isEmpty = await buf.isEmpty
        #expect(isEmpty)
    }

    @Test("Pop more elements than available")
    func overcommittedPopElements() async throws {
        let buf = CircularBuffer<String>(capacity: 5)
        await buf.push(["A", "B", "C"])
        let count = await buf.count
        #expect(count == 3)

        let testPops = await buf.pop(amount: 5)
        #expect(testPops?.count == 3)
        guard let testPops else {
            throw TestError.abort
        }
        #expect(testPops[0] == "A")
        #expect(testPops[1] == "B")
        #expect(testPops[2] == "C")
        let isEmpty = await buf.isEmpty
        #expect(isEmpty)
    }
}
