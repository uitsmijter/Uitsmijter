import Foundation

/// An intermediary`Authorization code` generated when a user authorizes a client to access protected resources
///  on their behalf. The client receives this token and exchanges it for an access token.
///
/// - Parameters:
///     - value: The content of the `Code`.
///
/// - Note: If `value` is not given while instantiating, the code has an arbitrary string with the length of 16.
struct Code: Codable, Equatable, ExpressibleByStringLiteral {
    typealias StringLiteralType = String

    /// The `Code`'s content
    var value: String = String.random(length: Constants.TOKEN.LENGTH)

    /// The method with which the code is presented
    var codeChallengeMethod: CodeChallengeMethod?

    /// The original challenge
    /// The client computes a `code_challenge` starting from the code_verifier
    /// The `code_challenge` must be sent in the first step of the authorization flow.
    ///
    /// - SeeAlso:
    ///   - codeChallengeHash
    var codeChallenge: String?

    /// Initialize a new Code with a random `value`
    init() {
    }

    /// Initialize a new Code with a given pre-generated `value`
    init(stringLiteral value: String) {
        self.value = value
    }

    /// Initialize a new Code with a given pre-generated `value`
    init(value: String) {
        self.init(stringLiteral: value)
    }

    /// Initialize a new Code with a random `value` and a `codeChallenge` of method `codeChallengeMethod`
    ///
    /// - Parameters:
    ///   - codeChallengeMethod: The method with which the code is presented
    ///   - codeChallenge: The original string (send in the first call)
    /// - SeeAlso:
    ///   - codeChallengeHash
    init(codeChallengeMethod: CodeChallengeMethod, codeChallenge: String) {
        self.codeChallengeMethod = codeChallengeMethod
        self.codeChallenge = codeChallenge
    }

    // MARK: - Equatable

    /// Compare one code with another
    static func ==(lhs: Code, rhs: Code) -> Bool { // swiftlint:disable:this operator_whitespace
        lhs.codeChallengeMethod == rhs.codeChallengeMethod
                && lhs.codeChallenge == rhs.codeChallenge
                && lhs.value == rhs.value
    }
}
