import Foundation

/// A thread-safe circular buffer implementation with fixed capacity using Swift actors.
///
/// A circular buffer (also known as a ring buffer) is a fixed-size data structure that overwrites
/// old data when the buffer is full. This implementation provides thread-safe operations for
/// concurrent access through Swift's actor model.
///
/// ## Usage Example
///
/// ```swift
/// let buffer = CircularBuffer<Int>(capacity: 20)
/// let dataSet1 = [Int](repeating: 1, count: 10)
/// let dataSet2 = [Int](repeating: 2, count: 10)
/// let dataSet3 = [Int](repeating: 3, count: 10)
///
/// await buffer.push(dataSet1)
/// await buffer.push(dataSet2)
/// // overwrite first 10 elements with 3rd data set
/// await buffer.push(dataSet3)
///
/// let data = await buffer.pop(amount: 10)
/// // data is equal to dataSet3
/// ```
///
/// - Note: This implementation uses Swift actors for thread safety.
public actor CircularBuffer<Element: Sendable> {

    /// Internal storage array for buffer elements.
    private var items: [Element?]

    /// Internal count of items in the buffer.
    private var _count = 0

    /// Maximum number of elements the buffer can hold.
    ///
    /// Once initialized, the capacity cannot be changed.
    private let capacity: Int

    /// Current write index in the circular buffer.
    ///
    /// Points to the next position where data will be written.
    private var headPosition = 0

    /// Current read index in the circular buffer.
    ///
    /// Points to the next position where data will be read.
    private var tailPosition = 0

    /// Continuations waiting for elements matching specific predicates.
    ///
    /// Each continuation will be resumed when an element matching its predicate is pushed to the buffer.
    private var waiters: [(predicate: (Element) -> Bool, continuation: CheckedContinuation<Element, Never>)] = []

    /// Number of elements currently stored in the buffer.
    ///
    /// This property is thread-safe through the actor isolation.
    public var count: Int {
        _count
    }

    /// Number of available slots in the buffer for new elements.
    ///
    /// Calculated as `capacity - count`.
    var available: Int {
        capacity - _count
    }

    /// Indicates whether the buffer is at full capacity.
    ///
    /// - Returns: `true` if the buffer contains `capacity` elements, `false` otherwise.
    var isFull: Bool {
        capacity == _count
    }

    /// Indicates whether the buffer is empty.
    ///
    /// - Returns: `true` if the buffer contains no elements, `false` otherwise.
    var isEmpty: Bool {
        headPosition == tailPosition && !isFull
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
    /// If the buffer is full, the oldest element is overwritten. This operation is thread-safe through actor isolation.
    ///
    /// - Parameter value: The element to add to the buffer.
    public func push(_ value: Element) {
        let wasFull = isFull
        items[headPosition] = value
        headPosition = (headPosition + 1) % capacity
        if wasFull {
            // When buffer is full, overwriting oldest element, so move tail
            tailPosition = (tailPosition + 1) % capacity
        } else {
            // Buffer not full, increase count
            _count += 1
        }

        // Notify any waiters that match this element
        notifyWaiters(for: value)
    }

    /// Notifies all waiting continuations whose predicates match the given element.
    ///
    /// This method is called internally after pushing elements to the buffer.
    /// It iterates through all registered waiters and resumes those whose predicates match.
    ///
    /// - Parameter element: The element to test against waiting predicates
    private func notifyWaiters(for element: Element) {
        var remainingWaiters: [(predicate: (Element) -> Bool, continuation: CheckedContinuation<Element, Never>)] = []

        for waiter in waiters {
            if waiter.predicate(element) {
                // Resume this waiter with the matching element
                waiter.continuation.resume(returning: element)
            } else {
                // Keep this waiter for future notifications
                remainingWaiters.append(waiter)
            }
        }

        waiters = remainingWaiters
    }

    /// Adds a single element to the buffer with configurable overflow behavior.
    ///
    /// - Parameters:
    ///   - value: The element to add to the buffer.
    ///   - drop: If `true`, the element is not added when the buffer is full.
    ///     If `false`, the oldest element is overwritten.
    /// - Returns: `1` if the value was not added (dropped), `0` if it was successfully added.
    @discardableResult public func push(_ value: Element, drop: Bool) -> Int {
        guard !isFull || !drop else {
            return 1
        }
        push(value)
        return 0
    }

    /// Adds multiple elements to the buffer.
    ///
    /// If the buffer becomes full during the operation, the oldest elements are overwritten.
    ///
    /// - Parameter values: An array of elements to add to the buffer.
    public func push(_ values: [Element]) {
        for idx in 0..<(values.count) {
            items[(headPosition + idx) % capacity] = values[idx]
        }

        let overflow = (_count + values.count) - capacity
        if overflow > 0 {
            // Buffer will overflow, move tail by overflow amount
            tailPosition = (tailPosition + overflow) % capacity
        }

        headPosition = (headPosition + values.count) % capacity
        let newCount = _count + values.count
        _count = min(newCount, capacity)
    }

    /// Adds multiple elements to the buffer with configurable overflow behavior.
    ///
    /// This operation is thread-safe through actor isolation.
    ///
    /// - Parameters:
    ///   - values: An array of elements to add to the buffer.
    ///   - drop: If `true`, elements are not added when the buffer is full.
    ///     If `false`, the oldest elements are overwritten.
    /// - Returns: The number of elements that were not added (dropped) due to buffer constraints.
    @discardableResult public func push(_ values: [Element], drop: Bool) -> Int {
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
        let newCount = _count + amount
        _count = min(newCount, capacity)

        return dropped
    }

    // MARK: - Pop

    /// Removes and returns a single element from the buffer.
    ///
    /// Elements are removed in FIFO (first-in, first-out) order. This operation is thread-safe through actor isolation.
    ///
    /// - Returns: The oldest element in the buffer, or `nil` if the buffer is empty.
    @discardableResult public func pop() -> Element? {
        guard !isEmpty else {
            return nil
        }

        let item = items[tailPosition]
        tailPosition = (tailPosition + 1) % capacity
        _count = max(_count - 1, 0)
        return item
    }

    /// Removes and returns multiple elements from the buffer.
    ///
    /// Elements are removed in FIFO (first-in, first-out) order. If the requested amount exceeds
    /// the number of available elements, only the available elements are returned.
    ///
    /// - Parameter amount: The number of elements to remove from the buffer.
    /// - Returns: An array of elements, or `nil` if the buffer is empty. The returned array may contain
    ///           fewer elements than requested if not enough elements are available.
    @discardableResult public func pop(amount: Int) -> [Element]? {
        let getAmount = amount > _count ? _count : amount
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
        _count = max(_count - getAmount, 0)

        return values
    }

    // MARK: - Waiting for Elements

    /// Waits asynchronously for an element matching the given predicate to be pushed to the buffer.
    ///
    /// This method suspends the calling task until an element matching the predicate is pushed.
    /// If an element already exists in the buffer that matches the predicate, it returns immediately
    /// with that element. Otherwise, it registers a continuation that will be resumed when a
    /// matching element is pushed.
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let buffer = CircularBuffer<String>(capacity: 100)
    ///
    /// Task {
    ///     // This will wait until a string containing "test" is pushed
    ///     let result = await buffer.waitForElement { $0.contains("test") }
    ///     print("Found: \(result)")
    /// }
    ///
    /// // Later, in another context:
    /// await buffer.push("This is a test message")
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe through actor isolation. Multiple tasks can wait simultaneously
    /// for different predicates, and each will be notified independently when matching elements arrive.
    ///
    /// - Parameter predicate: A closure that tests each element. Return `true` to match.
    /// - Returns: The most recent element that matches the predicate (either existing or newly pushed).
    public func waitForElement(where predicate: @escaping (Element) -> Bool) async -> Element {
        // First, check if an element already exists in the buffer
        // Search from newest to oldest to get the most recent match
        let currentElements = allElements()
        if let existing = currentElements.reversed().first(where: predicate) {
            return existing
        }

        // No existing element, so wait for a new one
        return await withCheckedContinuation { continuation in
            waiters.append((predicate: predicate, continuation: continuation))
        }
    }

    // MARK: - Query Methods

    /// Returns all elements in the buffer without removing them.
    ///
    /// Elements are returned in chronological order (oldest to newest), which is the same order
    /// they would be returned if using `pop`. This is a read-only operation that does not modify
    /// the buffer state.
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe through actor isolation.
    ///
    /// - Returns: An array of all elements currently in the buffer, or an empty array if the buffer is empty.
    ///            Elements are ordered from oldest (first) to newest (last).
    public func allElements() -> [Element] {
        guard !isEmpty else {
            return []
        }

        let currentCount = _count
        var result: [Element] = []
        result.reserveCapacity(currentCount)

        for idx in 0..<currentCount {
            if let item = items[(tailPosition + idx) % capacity] {
                result.append(item)
            }
        }

        return result
    }

}
