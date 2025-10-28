import Foundation

/// Extension providing a zero-value UUID constant
extension UUID {
    /// A UUID with all zeros (00000000-0000-0000-0000-000000000000)
    ///
    /// Useful as a placeholder or sentinel value when a UUID is required but has no meaningful value.
    ///
    /// ## Example
    /// ```swift
    /// let placeholder = UUID.empty  // 00000000-0000-0000-0000-000000000000
    /// ```
    static var empty: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000000")! // swiftlint:disable:this force_unwrapping
    }
}
