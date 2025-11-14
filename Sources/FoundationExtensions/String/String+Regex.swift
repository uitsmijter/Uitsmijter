import Foundation

/// Extends a `String` with regular expression functionality
///
/// - Important: Swift 5.5 does not have a build in regex, as swift 5.6 do
public extension String {

    /// Errors that can occur during regex matching
    enum StringRegexError: Error {
        /// No matches were found for the given pattern
        case noMatches
    }

    /// Extracts capture groups from a regular expression match
    ///
    /// Applies a regular expression pattern to the string and returns the matched groups.
    /// If the pattern contains capture groups, only the groups are returned (not the full match).
    /// If there are no capture groups, the full match is returned.
    ///
    /// - Parameter pattern: Regular expression pattern with optional capture groups
    /// - Returns: An array of strings for matched groups
    /// - Throws: `StringRegexError.noMatches` if no matches are found, or regex syntax errors
    ///
    /// ## Example
    /// ```swift
    /// try "Hello".groups(regex: "^.+$")  // ["Hello"]
    /// try "The 1 number".groups(regex: #"^The\s+(.+)\s+number$"#)  // ["1"]
    /// ```
    func groups(regex pattern: String) throws -> [String] {
        let stringRange = NSRange(
            startIndex..<endIndex,
            in: self
        )

        let expression = try NSRegularExpression(pattern: pattern, options: [])
        let matches = expression.matches(
            in: self,
            options: [],
            range: stringRange
        )

        guard let match = matches.first else {
            throw StringRegexError.noMatches
        }

        var groups: [String] = []
        for rangeIndex in 0..<match.numberOfRanges {
            let matchRange = match.range(at: rangeIndex)

            // Ignore matching the entire string (.first) when there is more
            if matchRange == stringRange && match.numberOfRanges != 1 {
                continue
            }

            // Extract the substring matching the capture group
            if let substringRange = Range(matchRange, in: self) {
                let capture = String(self[substringRange])
                groups.append(capture)
            }
        }
        return groups
    }

}
