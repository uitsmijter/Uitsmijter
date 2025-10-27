import Foundation

/// Extension providing URL-safe slug generation from strings
public extension String {
    private static let slugSafeCharacters = CharacterSet(
        charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-"
    )

    /// Converts the string to a URL-safe slug
    ///
    /// Generates a lowercase, hyphen-separated slug suitable for use in URLs.
    /// Non-ASCII characters are converted using lossy ASCII conversion, and any
    /// characters not in the safe set are replaced with hyphens.
    ///
    /// - Returns: A URL-safe slug string, or `nil` if conversion fails
    ///
    /// ## Example
    /// ```swift
    /// "Hello World".slug  // "hello-world"
    /// "Café & Bar".slug   // "cafe-bar"
    /// ```
    var slug: String? {
        get {
            if let data = data(using: .ascii, allowLossyConversion: true) {
                if let str = String(data: data, encoding: .ascii) {
                    let urlComponents = str.lowercased().components(separatedBy: String.slugSafeCharacters.inverted)
                    return urlComponents.filter { component in
                        component != ""
                    }
                    .joined(separator: "-")
                }
            }
            return nil
        }
    }
}
