import Foundation
import Dispatch

/// CircularBuffer
///
///
///
/// ```swift
/// var buffer = CircularBuffer<Int>(capacity: 20)
/// let dataSet1 = [Int](repeating: 1, count: 10)
/// let dataSet2 = [Int](repeating: 2, count: 10)
/// let dataSet3 = [Int](repeating: 3, count: 10)
///
/// buffer.push(dataSet1)
/// buffer.push(dataSet2)
/// // overwrite first 10 elements with 3d data set
/// buffer.push(dataSet3)
///
/// var data = rbuf.pop(amount: 10)
/// // data is equal to dataSet3
///
/// ```
public struct CircularBuffer<Element> {

    private var items: [Element?]
    private var _count = 0
    private let lock = DispatchSemaphore(value: 1)
    let pushlock = NSLock()

    /// Maximum number of elements in the buffer
    private(set) var capacity = 0
    /// Current write index
    private(set) var headPosition = 0
    /// Current read index
    private(set) var tailPosition = 0

    /// Number of current elements in the buffer
    var count: Int {
        lock.wait()
        defer {
            lock.signal()
        }
        return _count
    }

    /// Slots in the buffer available for being filled
    var available: Int {
        return capacity - count
    }

    /// Returns true if buffer is full
    var isFull: Bool {
        return capacity == count
    }

    /// Returns true if buffer is empty
    var isEmpty: Bool {
        return headPosition == tailPosition && !isFull
    }

    /// Creates a new `CircularBuffer`
    /// - parameters:
    ///   - capacity: Maximum number of elements in the buffer
    public init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        items = [Element?](repeating: nil, count: self.capacity)
    }

    // MARK: - Push

    /// Push single element (overwrite on overflow by default)
    public mutating func push(_ value: Element) {
        pushlock.lock()
        defer {
            pushlock.unlock()
        }
        items[headPosition] = value
        headPosition = (headPosition + 1) % capacity
        atomicCountAdd(1)
    }

    /// Push single element with specific overwrite behavior
    ///
    /// - parameters:
    ///    - value: Value to write
    ///    - drop: Skip (do not add) element if buffer is full
    ///
    /// - returns: 1 if value wasn’t added, otherwise 0
    @discardableResult public mutating func push(_ value: Element, drop: Bool) -> Int {
        guard !isFull || !drop else {
            return 1
        }
        push(value)
        return 0
    }

    /// Push multiple elements (overwrite on overflow by default)
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

    /// Push multiple elements with specific overwrite behavior
    ///
    /// - parameters:
    ///    - values: Values to write
    ///    - drop: Skip (do not add) elements if buffer is full
    ///
    /// - returns: Number of elements that were not added
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

    /// Pop single element
    ///
    /// - returns:
    ///     Element or `nil` if buffer is empty
    @discardableResult public mutating func pop() -> Element? {
        guard !isEmpty else {
            return nil
        }

        let item = items[tailPosition]
        tailPosition = (tailPosition + 1) % capacity
        atomicCountAdd(-1)
        return item
    }

    /// Pop multiple elements
    ///
    /// - parameters:
    ///    - amount: Number of elements to read
    ///
    /// -  returns:
    ///    Array of elements or `nil` if requested amount is greater than current buffer size
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

    // MARK: - privates

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
