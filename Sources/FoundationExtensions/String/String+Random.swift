import Foundation

/// Extends a `String` with functions to generate a random literal
///
public extension String {

    /// Character set used for building a random string
    ///
    /// Defines the set of characters that can be used when generating random strings.
    struct RandomCharacterSet {
        /// Type alias for the character set value
        typealias Value = String

        /// The actual string containing all allowed characters
        var value: Value = ""

        /// Alphanumeric character set (a-z, A-Z, 0-9)
        ///
        /// Contains lowercase letters, uppercase letters, and digits.
        /// - Returns: A `RandomCharacterSet` with alphanumeric characters
        public static var aZ09: RandomCharacterSet {
            get {
                RandomCharacterSet(value: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
            }
        }

        /// Code verifier character set for OAuth PKCE
        ///
        /// Contains alphanumeric characters plus hyphen, period, underscore, and tilde,
        /// as specified in RFC 7636 for PKCE code verifiers.
        /// - Returns: A `RandomCharacterSet` suitable for OAuth PKCE code verifiers
        public static var codeVerifier: RandomCharacterSet {
            get {
                RandomCharacterSet(value: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
            }
        }

        /// Creates a custom character set from a string
        ///
        /// - Parameter characterSet: A string containing all allowed characters
        /// - Returns: A `RandomCharacterSet` with the specified characters
        static func custom(_ characterSet: String) -> RandomCharacterSet {
            RandomCharacterSet(value: characterSet)
        }
    }

    /// Generates a random string of variable length
    ///
    /// Creates a random string by selecting characters from the specified character set.
    ///
    /// - Parameters:
    ///   - length: The length of the generated string
    ///   - letterSet: A set of characters to build the string from. Defaults to alphanumeric characters (a-z, A-Z, 0-9)
    /// - Returns: A randomly generated string of the specified length
    ///
    /// ## Example
    /// ```swift
    /// let randomToken = String.random(length: 32)
    /// let customRandom = String.random(length: 16, of: .codeVerifier)
    /// ```
    ///
    static func random(length: Int, of letterSet: RandomCharacterSet = RandomCharacterSet.aZ09) -> String {
        let letters = letterSet.value
        return String((0..<length).compactMap { _ in
            letters.randomElement()
        })
    }

}
