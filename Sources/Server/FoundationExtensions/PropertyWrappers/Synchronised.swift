import Foundation

/// Synchronized a variable with posix_lock
@propertyWrapper public struct Synchronised<T> {
    private let lock = NSLock()

    private var _wrappedValue: T
    public var wrappedValue: T {
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

    public init(wrappedValue: T) {
        self._wrappedValue = wrappedValue
    }
}
