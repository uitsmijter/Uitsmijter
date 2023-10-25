import Foundation

/// When a AuthRequest with PKCE is requested, the client has to set a `code_challenge`. This `` describes the possible
/// encoding methods.
///
/// - SeeAlso: AuthRequestPKCE
enum CodeChallengeMethod: String, Codable {
    /// Do not use a challenge
    case none // swiftlint:disable:this discouraged_none_name

    /// A plain code challenge ist provided
    case plain

    /// A code challenge ist provided that is encoded with the SHA256 algorithm
    case sha256 = "S256"
}
