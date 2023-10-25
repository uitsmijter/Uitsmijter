import Foundation
import Vapor

protocol TokenRequestProtocol: Codable {

    var grant_type: GrantTypes { get }

    var client_id: String { get }

    var client_secret: String? { get }
}

struct TokenRequest: TokenRequestProtocol, ClientIdProtocol, /*RedirectUriProtocol, */  ScopesProtocol {

    var grant_type: GrantTypes

    var client_id: String

    var client_secret: String?

    var scope: String?
}

struct CodeTokenRequest: TokenRequestProtocol {

    // MARK: - Protocol Implementation

    var grant_type: GrantTypes

    var client_id: String

    var client_secret: String?

    var scope: String?

    // MARK: - Code Implementation

    let code: Code.StringLiteralType

    var code_challenge_method: CodeChallengeMethod?

    var code_verifier: String?
}

import CryptoSwift

extension CodeTokenRequest {
    /// The SHA-256 hash in Base64 of the original code_verifier
    ///
    /// code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
    ///
    /// - SeeAlso:
    ///   - codeChallenge
    var code_challenge: String? {
        get {
            if let code_verifier {
                return code_verifier.data(using: .ascii)?.sha256().base64String()
                        .replacingOccurrences(of: "+", with: "-")
                        .replacingOccurrences(of: "/", with: "_")
                        .replacingOccurrences(of: "=", with: "")
            }
            return nil
        }
    }
}

struct RefreshTokenRequest: TokenRequestProtocol {

    var grant_type: GrantTypes

    var client_id: String

    var client_secret: String?

    // MARK: - Refresh Token Implementation

    let refresh_token: String
}

struct PasswordTokenRequest: TokenRequestProtocol {

    // MARK: - Protocol Implementation

    var grant_type: GrantTypes

    var client_id: String

    var client_secret: String?

    var scope: String?

    // MARK: - Code Implementation

    let username: String

    let password: String
}
