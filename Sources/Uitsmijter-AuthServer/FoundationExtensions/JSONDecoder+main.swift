import Foundation

/// Extension providing a shared JSONDecoder instance
extension JSONDecoder {
    /// Shared JSONDecoder instance for application-wide use
    ///
    /// Provides a single, reusable decoder instance to avoid creating new instances repeatedly.
    static let main = JSONDecoder()

    /// Configures the main JSONDecoder instance
    ///
    /// Allows customization of the shared decoder instance with specific configuration.
    ///
    /// - Parameter config: A closure that receives the main decoder for configuration
    ///
    /// ## Example
    /// ```swift
    /// JSONDecoder.configureMainDecoder { decoder in
    ///     decoder.dateDecodingStrategy = .iso8601
    /// }
    /// ```
    static func configureMainDecoder(config: (_ decoder: JSONDecoder) -> Void) {
        config(main)
    }
}
