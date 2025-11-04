import Foundation

/// Property wrapper providing thread-safe access to a value using NSLock
///
/// Wraps any value type with automatic locking to ensure thread-safe read and write access.
/// Uses NSLock internally to synchronize access from multiple threads.
///
/// ## Example
/// ```swift
/// class Counter {
///     @Synchronised var count = 0
///
///     func increment() {
///         count += 1  // Thread-safe increment
///     }
/// }
/// ```
@propertyWrapper struct Synchronised<T> {
    private let lock = NSLock()

    private var _wrappedValue: T

    /// The wrapped value with thread-safe access
    ///
    /// Reading and writing this property is automatically protected by a lock.
    var wrappedValue: T {
        get {
            lock.lock()
            defer {
                lock.unlock()
            }
            return _wrappedValue
        }
        set {
            lock.lock()
            defer {
                lock.unlock()
            }
            _wrappedValue = newValue
        }
    }

    /// Creates a new synchronized property wrapper
    ///
    /// - Parameter wrappedValue: The initial value to wrap with thread-safe access
    init(wrappedValue: T) {
        self._wrappedValue = wrappedValue
    }
}
