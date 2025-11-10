import Foundation
import Synchronization

/// Property wrapper providing thread-safe access to a value using Swift 6 Mutex
///
/// Wraps any value type with automatic locking to ensure thread-safe read and write access.
/// Uses Swift 6's cross-platform Mutex internally to synchronize access from multiple threads.
/// Mutex provides compile-time safety guarantees and works across macOS, Linux, and Windows.
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
///
/// ## Implementation Note
/// Uses a class-based wrapper to hold the noncopyable Mutex, allowing the property wrapper
/// itself to be used in stored properties while maintaining thread-safety guarantees.
@propertyWrapper final class Synchronised<T: Sendable>: @unchecked Sendable {
    private let mutex: Mutex<T>

    /// The wrapped value with thread-safe access
    ///
    /// Reading and writing this property is automatically protected by a mutex.
    var wrappedValue: T {
        get {
            mutex.withLock { $0 }
        }
        set {
            mutex.withLock { $0 = newValue }
        }
    }

    /// Creates a new synchronized property wrapper
    ///
    /// - Parameter wrappedValue: The initial value to wrap with thread-safe access
    init(wrappedValue: sending T) {
        self.mutex = Mutex(wrappedValue)
    }
}
