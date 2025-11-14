import Foundation

/// Extension providing convenient check for non-empty arrays
public extension Array {
    /// Returns `true` if the array contains at least one element
    ///
    /// This is a convenience property that negates `isEmpty` for more readable code.
    ///
    /// ## Example
    /// ```swift
    /// let items = [1, 2, 3]
    /// if items.isNotEmpty {
    ///     print("Array has elements")
    /// }
    /// ```
    var isNotEmpty: Bool {
        !isEmpty
    }
}
