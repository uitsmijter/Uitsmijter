import Foundation

/// Extends a `String` with regular expression
///
/// - Important: Swift 5.5 does not have a build in regex, as swift 5.6 do
extension String {

    enum StringRegexError: Error {
        case noMatches
    }

    /// Match groups with regex in a string
    ///
    /// Example:
    ///     try "Hello".groups(regex: "^.+$") // "Hello"
    ///     try "The 1 number".groups(regex: #"^The\s+(.+)\s+number$"#) // ["1"]
    ///
    /// - Parameter pattern: Regular expressions string that should apply to match groups in the string
    /// - Returns: An array of strings for matched groups.
    /// - Throws: An error of the regular expression ha an error
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
