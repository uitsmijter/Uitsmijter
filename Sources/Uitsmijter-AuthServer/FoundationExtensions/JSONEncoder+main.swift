import Foundation

/// Extension providing a shared JSONEncoder instance
public extension JSONEncoder {
    /// Shared JSONEncoder instance for application-wide use
    ///
    /// Provides a single, reusable encoder instance to avoid creating new instances repeatedly.
    static let main = JSONEncoder()

    /// Configures the main JSONEncoder instance
    ///
    /// Allows customization of the shared encoder instance with specific configuration.
    ///
    /// - Parameter config: A closure that receives the main encoder for configuration
    ///
    /// ## Example
    /// ```swift
    /// JSONEncoder.configureMainEncoder { encoder in
    ///     encoder.outputFormatting = .prettyPrinted
    /// }
    /// ```
    static func configureMainEncoder(config: (_ encoder: JSONEncoder) -> Void) {
        config(main)
    }
}
