import Foundation

/// Extends a `String` with regular expression
///
/// - Important: Swift 5.5 does not have a build in regex, as swift 5.6 do
extension String {

    /// Match groups with regex in a string
    ///
    /// Example:
    ///     try "Hello".groups(regex: "^.+$") // "Hello"
    ///     try "The 1 number".groups(regex: #"^The\s+(.+)\s+number$"#) // ["1"]
    ///
    /// - Parameter pattern: Regular expressions string that should apply to match groups in the string
    /// - Returns: An array of strings for matched groups.
    /// - Throws: An error of the regular expression ha an error
    func matchesWildcard(regex pattern: String) -> Bool {
        let regexPattern = "^"
        + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\.", with: "\\.")
            .replacingOccurrences(of: "\\*", with: "[a-zA-Z0-9\\-_]+")
        + "$"
        
        return self.range(of: regexPattern, options: .regularExpression) != nil
    }

}
