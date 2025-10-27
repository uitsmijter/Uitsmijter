import Foundation
import Dispatch

/// A thread-safe circular buffer implementation with fixed capacity.
///
/// A circular buffer (also known as a ring buffer) is a fixed-size data structure that overwrites
/// old data when the buffer is full. This implementation provides thread-safe operations for
/// concurrent access.
///
/// ## Usage Example
///
/// ```swift
/// var buffer = CircularBuffer<Int>(capacity: 20)
/// let dataSet1 = [Int](repeating: 1, count: 10)
/// let dataSet2 = [Int](repeating: 2, count: 10)
/// let dataSet3 = [Int](repeating: 3, count: 10)
///
/// buffer.push(dataSet1)
/// buffer.push(dataSet2)
/// // overwrite first 10 elements with 3rd data set
/// buffer.push(dataSet3)
///
/// var data = buffer.pop(amount: 10)
/// // data is equal to dataSet3
/// ```
///
/// - Note: This implementation uses semaphores and locks for thread safety.
public struct CircularBuffer<Element> {

    /// Internal storage array for buffer elements.
    private var items: [Element?]

    /// Internal count variable protected by lock.
    private var _count = 0

    /// Semaphore for thread-safe count operations.
    private let lock = DispatchSemaphore(value: 1)

    /// Lock for thread-safe push operations.
    let pushlock = NSLock()

    /// Maximum number of elements the buffer can hold.
    ///
    /// Once initialized, the capacity cannot be changed.
    private(set) var capacity = 0

    /// Current write index in the circular buffer.
    ///
    /// Points to the next position where data will be written.
    private(set) var headPosition = 0

    /// Current read index in the circular buffer.
    ///
    /// Points to the next position where data will be read.
    private(set) var tailPosition = 0

    /// Number of elements currently stored in the buffer.
    ///
    /// This property is thread-safe and protected by a semaphore lock.
    public var count: Int {
        lock.wait()
        defer {
            lock.signal()
        }
        return _count
    }

    /// Number of available slots in the buffer for new elements.
    ///
    /// Calculated as `capacity - count`.
    var available: Int {
        return capacity - count
    }

    /// Indicates whether the buffer is at full capacity.
    ///
    /// - Returns: `true` if the buffer contains `capacity` elements, `false` otherwise.
    var isFull: Bool {
        return capacity == count
    }

    /// Indicates whether the buffer is empty.
    ///
    /// - Returns: `true` if the buffer contains no elements, `false` otherwise.
    var isEmpty: Bool {
        return headPosition == tailPosition && !isFull
    }

    /// Creates a new circular buffer with the specified capacity.
    ///
    /// - Parameter capacity: Maximum number of elements the buffer can hold. Must be greater than 0.
    /// - Precondition: `capacity` must be greater than 0.
    public init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        items = [Element?](repeating: nil, count: self.capacity)
    }

    // MARK: - Push

    /// Adds a single element to the buffer.
    ///
    /// If the buffer is full, the oldest element is overwritten. This operation is thread-safe.
    ///
    /// - Parameter value: The element to add to the buffer.
    public mutating func push(_ value: Element) {
        pushlock.lock()
        defer {
            pushlock.unlock()
        }
        items[headPosition] = value
        headPosition = (headPosition + 1) % capacity
        atomicCountAdd(1)
    }

    /// Adds a single element to the buffer with configurable overflow behavior.
    ///
    /// This operation is thread-safe.
    ///
    /// - Parameters:
    ///   - value: The element to add to the buffer.
    ///   - drop: If `true`, the element is not added when the buffer is full.
    ///     If `false`, the oldest element is overwritten.
    /// - Returns: `1` if the value was not added (dropped), `0` if it was successfully added.
    @discardableResult public mutating func push(_ value: Element, drop: Bool) -> Int {
        guard !isFull || !drop else {
            return 1
        }
        push(value)
        return 0
    }

    /// Adds multiple elements to the buffer.
    ///
    /// If the buffer becomes full during the operation, the oldest elements are overwritten.
    /// This operation is thread-safe.
    ///
    /// - Parameter values: An array of elements to add to the buffer.
    public mutating func push(_ values: [Element]) {
        pushlock.lock()
        defer {
            pushlock.unlock()
        }
        for idx in 0..<(values.count) {
            items[(headPosition + idx) % capacity] = values[idx]
        }
        headPosition = (headPosition + values.count) % capacity
        atomicCountAdd(values.count)
    }

    /// Adds multiple elements to the buffer with configurable overflow behavior.
    ///
    /// This operation is thread-safe.
    ///
    /// - Parameters:
    ///   - values: An array of elements to add to the buffer.
    ///   - drop: If `true`, elements are not added when the buffer is full.
    ///     If `false`, the oldest elements are overwritten.
    /// - Returns: The number of elements that were not added (dropped) due to buffer constraints.
    @discardableResult public mutating func push(_ values: [Element], drop: Bool) -> Int {
        pushlock.lock()
        defer {
            pushlock.unlock()
        }
        guard !(isFull && drop) else {
            return values.count
        }

        var dropped = 0
        var amount = values.count
        if values.count > available && drop {
            amount = available
            dropped = values.count - amount
        }

        for idx in 0..<(amount) {
            items[(headPosition + idx) % capacity] = values[idx]
        }

        headPosition = (headPosition + amount) % capacity
        atomicCountAdd(amount)

        return dropped
    }

    // MARK: - Pop

    /// Removes and returns a single element from the buffer.
    ///
    /// Elements are removed in FIFO (first-in, first-out) order. This operation is thread-safe.
    ///
    /// - Returns: The oldest element in the buffer, or `nil` if the buffer is empty.
    @discardableResult public mutating func pop() -> Element? {
        guard !isEmpty else {
            return nil
        }

        let item = items[tailPosition]
        tailPosition = (tailPosition + 1) % capacity
        atomicCountAdd(-1)
        return item
    }

    /// Removes and returns multiple elements from the buffer.
    ///
    /// Elements are removed in FIFO (first-in, first-out) order. If the requested amount exceeds
    /// the number of available elements, only the available elements are returned. This operation is thread-safe.
    ///
    /// - Parameter amount: The number of elements to remove from the buffer.
    /// - Returns: An array of elements, or `nil` if the buffer is empty. The returned array may contain
    ///           fewer elements than requested if not enough elements are available.
    @discardableResult public mutating func pop(amount: Int) -> [Element]? {
        let getAmount = amount > count ? count : amount
        if isEmpty {
            return nil
        }

        var values = [Element]()
        for idx in 0..<(getAmount) {
            if let item = items[(tailPosition + idx) % capacity] {
                values.append(item)
            }
        }
        tailPosition = (tailPosition + getAmount) % capacity
        atomicCountAdd(-getAmount)

        return values
    }

    // MARK: - Private Methods

    /// Atomically updates the internal count with thread safety.
    ///
    /// This method uses a semaphore lock to ensure thread-safe count modifications.
    ///
    /// - Parameter value: The value to add to the current count (can be negative for subtraction).
    private mutating func atomicCountAdd(_ value: Int) {
        lock.wait()
        defer {
            lock.signal()
        }
        if _count + value > capacity {
            _count = (_count + value) % capacity
        } else {
            _count += value
        }
    }
}
