import Foundation

/// Extends a `String` with wildcard pattern matching
///
/// - Important: Swift 5.5 does not have a build in regex, as swift 5.6 do
public extension String {

    /// Checks if the string matches a wildcard pattern
    ///
    /// Converts a simple wildcard pattern (with `*` characters) into a regular expression
    /// and checks if the string matches. The wildcard `*` matches alphanumeric characters,
    /// hyphens, and underscores.
    ///
    /// - Parameter pattern: Wildcard pattern where `*` matches one or more characters
    /// - Returns: `true` if the string matches the wildcard pattern
    ///
    /// ## Example
    /// ```swift
    /// "hello-world".matchesWildcard(regex: "hello-*")     // true
    /// "api-v1-test".matchesWildcard(regex: "api-*-test")  // true
    /// "test".matchesWildcard(regex: "prod-*")             // false
    /// ```
    func matchesWildcard(regex pattern: String) -> Bool {
        let regexPattern = "^"
            + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\.", with: "\\.")
            .replacingOccurrences(of: "\\*", with: "[a-zA-Z0-9\\-_]+")
            + "$"

        return self.range(of: regexPattern, options: .regularExpression) != nil
    }

}
