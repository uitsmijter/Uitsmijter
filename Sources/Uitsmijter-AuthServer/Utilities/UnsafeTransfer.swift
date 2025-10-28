import Foundation

// MARK: - Concurrency Utilities

/// A wrapper for transferring non-`Sendable` types across concurrency boundaries.
///
/// This type uses `@unchecked Sendable` to allow transferring values that are
/// not marked as `Sendable`, but are known to be thread-safe in the specific
/// usage context.
///
/// ## Usage
///
/// ```swift
/// let nonSendableValue = FileChange.added(url)
/// let wrapper = UnsafeTransfer(nonSendableValue)
/// Task {
///     await processChange(wrapper.wrappedValue)
/// }
/// ```
///
/// - Warning: Only use this when you have verified that the wrapped value's
///   usage is thread-safe. Misuse can lead to data races and undefined behavior.
///
/// - Important: The caller is responsible for ensuring thread safety.
///   Common safe patterns include:
///   - Transferring immutable values
///   - Values that are only accessed from a single actor
///   - Values protected by external synchronization
struct UnsafeTransfer<T>: @unchecked Sendable {
    /// The wrapped value that can be transferred across concurrency boundaries.
    public let wrappedValue: T

    /// Creates a new unsafe transfer wrapper.
    ///
    /// - Parameter wrappedValue: The value to wrap for transfer
    /// - Warning: Ensure the wrapped value's usage is thread-safe before using this
    public init(_ wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}
