import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@Suite("Synchronised Property Wrapper Tests")
struct SynchronisedTest {

    // Test class using Synchronised property wrapper
    final class Counter: @unchecked Sendable {
        @Synchronised var count: Int

        init(initialCount: Int = 0) {
            self.count = initialCount
        }

        func set(_ value: Int) {
            count = value
        }

        func get() -> Int {
            count
        }
    }

    @Test("Synchronised initializes with correct value")
    func initializesWithCorrectValue() {
        let counter = Counter(initialCount: 42)
        #expect(counter.count == 42)
    }

    @Test("Synchronised allows reading values")
    func allowsReading() {
        let counter = Counter(initialCount: 10)
        let value = counter.count

        #expect(value == 10)
    }

    @Test("Synchronised allows writing values")
    func allowsWriting() {
        let counter = Counter(initialCount: 0)
        counter.count = 100

        #expect(counter.count == 100)
    }

    @Test("Synchronised allows set operations")
    func allowsSet() {
        let counter = Counter(initialCount: 5)
        counter.set(10)
        counter.set(15)

        #expect(counter.count == 15)
    }

    @Test("Synchronised allows get operations")
    func allowsGet() {
        let counter = Counter(initialCount: 10)
        let value = counter.get()

        #expect(value == 10)
    }

    @Test("Synchronised works with different types")
    func worksWithDifferentTypes() {
        class StringHolder {
            @Synchronised var text: String

            init(text: String) {
                self.text = text
            }
        }

        class BoolHolder {
            @Synchronised var flag: Bool

            init(flag: Bool) {
                self.flag = flag
            }
        }

        let stringHolder = StringHolder(text: "Hello")
        #expect(stringHolder.text == "Hello")

        stringHolder.text = "World"
        #expect(stringHolder.text == "World")

        let boolHolder = BoolHolder(flag: true)
        #expect(boolHolder.flag == true)

        boolHolder.flag = false
        #expect(boolHolder.flag == false)
    }

    @Test("Synchronised handles concurrent writes without crashes", .timeLimit(.minutes(1)))
    func handlesConcurrentWrites() async {
        let counter = Counter(initialCount: 0)
        let iterations = 100
        let threadCount = 10

        await withTaskGroup(of: Void.self) { group in
            // Spawn multiple tasks that write different values
            for threadIndex in 0..<threadCount {
                group.addTask {
                    for iteration in 0..<iterations {
                        // Each thread writes a unique value
                        let value = threadIndex * iterations + iteration
                        counter.set(value)
                    }
                }
            }

            await group.waitForAll()
        }

        // The important thing is that we didn't crash and the counter has a valid value
        // We can't predict the final value due to race conditions in which write wins
        // but we can verify the counter is still functional
        let finalValue = counter.get()
        #expect(finalValue >= 0)
        #expect(finalValue < (threadCount * iterations))
    }

    @Test("Synchronised handles concurrent reads without crashes", .timeLimit(.minutes(1)))
    func handlesConcurrentReads() async {
        let counter = Counter(initialCount: 42)
        let readsPerThread = 100
        let threadCount = 10

        // Use actor to collect read results safely
        actor ResultCollector {
            var results: [Int] = []

            func append(_ value: Int) {
                results.append(value)
            }

            func getResults() -> [Int] {
                results
            }
        }

        let collector = ResultCollector()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<threadCount {
                group.addTask {
                    for _ in 0..<readsPerThread {
                        let value = counter.get()
                        await collector.append(value)
                    }
                }
            }

            await group.waitForAll()
        }

        // All reads should have returned 42 since we never changed the value
        let results = await collector.getResults()
        #expect(results.count == threadCount * readsPerThread)
        #expect(results.allSatisfy { $0 == 42 })
    }

    @Test("Synchronised handles concurrent read-write mix without crashes", .timeLimit(.minutes(1)))
    func handlesConcurrentReadWriteMix() async {
        let counter = Counter(initialCount: 100)

        // Use actor for thread-safe collection of read values
        actor ReadValuesCollector {
            var values: [Int] = []

            func append(_ value: Int) {
                values.append(value)
            }

            func getCount() -> Int {
                values.count
            }
        }

        let collector = ReadValuesCollector()

        await withTaskGroup(of: Void.self) { group in
            // Writers - each writes a unique value
            for i in 0..<50 {
                group.addTask {
                    counter.set(100 + i)
                }
            }

            // Readers
            for _ in 0..<50 {
                group.addTask {
                    let value = counter.get()
                    await collector.append(value)
                }
            }

            await group.waitForAll()
        }

        // Verify that reads happened without crashes
        let readCount = await collector.getCount()
        #expect(readCount == 50)

        // Verify counter is still in a valid state
        let finalValue = counter.get()
        #expect(finalValue >= 100)
        #expect(finalValue < 150)
    }

    @Test("Synchronised works with struct types")
    func worksWithStructTypes() {
        struct Point {
            // swiftlint:disable:next identifier_name
            var x: Int
            // swiftlint:disable:next identifier_name
            var y: Int
        }

        class PointHolder {
            @Synchronised var point: Point

            init(point: Point) {
                self.point = point
            }
        }

        let holder = PointHolder(point: Point(x: 10, y: 20))
        #expect(holder.point.x == 10)
        #expect(holder.point.y == 20)

        holder.point = Point(x: 30, y: 40)
        #expect(holder.point.x == 30)
        #expect(holder.point.y == 40)
    }

    @Test("Synchronised works with optional types")
    func worksWithOptionalTypes() {
        class OptionalHolder {
            @Synchronised var value: Int?

            init(value: Int? = nil) {
                self.value = value
            }
        }

        let holder = OptionalHolder()
        #expect(holder.value == nil)

        holder.value = 42
        #expect(holder.value == 42)

        holder.value = nil
        #expect(holder.value == nil)
    }

    @Test("Synchronised handles high contention without crashes", .timeLimit(.minutes(1)))
    func handlesHighContention() async {
        let counter = Counter(initialCount: 0)
        let operations = 100
        let threads = 100

        await withTaskGroup(of: Void.self) { group in
            for threadIndex in 0..<threads {
                group.addTask {
                    for operationIndex in 0..<operations {
                        // Write a unique value
                        let value = threadIndex * operations + operationIndex
                        counter.set(value)
                    }
                }
            }

            await group.waitForAll()
        }

        // Verify no crash occurred and counter is in valid state
        let finalValue = counter.get()
        #expect(finalValue >= 0)
        #expect(finalValue < (operations * threads))
    }
}
