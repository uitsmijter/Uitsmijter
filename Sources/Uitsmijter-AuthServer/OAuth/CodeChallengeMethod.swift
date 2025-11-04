import Foundation

/// The method used to encode the code challenge in PKCE (Proof Key for Code Exchange).
///
/// When using PKCE with an authorization request, the client must provide a
/// `code_challenge` that is derived from a `code_verifier`. This enum describes
/// the encoding method used to generate the challenge from the verifier.
///
/// ## Topics
///
/// ### Challenge Methods
/// - ``none``
/// - ``plain``
/// - ``sha256``
///
/// ## See Also
/// - ``AuthRequestPKCE``
enum CodeChallengeMethod: String, Codable, Sendable {
    /// No code challenge is used.
    ///
    /// - Warning: This option should not be used in production as it provides
    ///   no additional security. PKCE should always use either `plain` or `sha256`.
    case none // swiftlint:disable:this discouraged_none_name

    /// The code challenge is the plain code verifier.
    ///
    /// The `code_challenge` equals the `code_verifier`. This method provides
    /// basic PKCE protection but is less secure than SHA256.
    ///
    /// - Note: Use `sha256` instead for better security when possible.
    case plain

    /// The code challenge is the SHA256 hash of the code verifier.
    ///
    /// The `code_challenge` is computed as:
    /// ```
    /// code_challenge = base64urlEncode(SHA256(ASCII(code_verifier)))
    /// ```
    ///
    /// This is the recommended method for PKCE as it provides the strongest
    /// protection against authorization code interception attacks.
    case sha256 = "S256"
}
