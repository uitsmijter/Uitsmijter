import Foundation

/// Extension providing a shared `JSONEncoder` instance for the Logger module.
extension JSONEncoder {
    /// A shared `JSONEncoder` instance used throughout the Logger module.
    ///
    /// This encoder is configured with ISO 8601 date encoding strategy by default.
    static let main = JSONEncoder()

    /// Configures the shared main encoder with custom settings.
    ///
    /// This method allows modification of the shared encoder's configuration.
    ///
    /// - Parameter config: A closure that receives the main encoder for configuration.
    ///
    /// ## Example
    ///
    /// ```swift
    /// JSONEncoder.configureMainEncoder { encoder in
    ///     encoder.dateEncodingStrategy = .iso8601
    ///     encoder.outputFormatting = .prettyPrinted
    /// }
    /// ```
    static func configureMainEncoder(config: (_ encoder: JSONEncoder) -> Void) {
        config(main)
    }
}
