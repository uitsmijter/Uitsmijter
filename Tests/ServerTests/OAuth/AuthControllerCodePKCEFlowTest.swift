import Foundation
import XCTVapor
import CryptoSwift
@testable import Server

/// https://www.oauth.com/oauth2-servers/pkce/
///
final class AuthControllerCodePKCEFlowTest: XCTestCase {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()
    let app = Application(.testing)

    /// When the native app begins the authorization request, instead of immediately launching a
    /// browser, the client first creates what is known as a “code verifier“. This is a cryptographically
    /// random string using the characters A-Z, a-z, 0-9, and the punctuation characters -._~ (hyphen, period,
    /// underscore, and tilde), between 43 and 128 characters long.
    let codeVerifier = String.random(length: Int.random(in: 43...128), of: .codeVerifier)

    var codeVerifierSHA256B64: String {
        get {
            // swiftlint:disable:next force_unwrapping
            codeVerifier.data(using: .ascii)!.sha256().base64String()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
        }
    }

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent)

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    /// Once the app has generated the code verifier, it uses that to derive the code challenge. For devices
    /// that can perform a SHA256 hash, the code challenge is a Base64-URL-encoded string of the SHA256 hash of
    /// the code verifier. Clients that do not have the ability to perform a SHA256 hash are permitted to use the
    /// plain code verifier string as the challenge.
    func testCodeVerifier() {
        XCTAssertGreaterThanOrEqual(codeVerifier.count, 43)
        XCTAssertLessThanOrEqual(codeVerifier.count, 128)
    }

    /// Characters of the Base64 alphabet can be grouped into four groups:
    /// Uppercase letters (indices 0-25): ABCDEFGHIJKLMNOPQRSTUVWXYZ
    /// Lowercase letters (indices 26-51): abcdefghijklmnopqrstuvwxyz
    /// Digits (indices 52-61): 0123456789
    /// Special symbols (indices 62-63):
    func testCodeVerifierH256() throws {
        XCTAssertNoThrow(try codeVerifierSHA256B64.groups(regex: "^[A-Za-z0-9+-_]+$"))
    }

    func testValidUsersCodeFlowPacePlainMissingCodeChallenge() async throws {
        // get the tenant to save the id into the Payload
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("no tenant in client")
            throw TestError.abort
        }

        let response = try app.sendRequest(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123&"
                        + "&code_challenge_method=plain",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                }
        )
        XCTAssertEqual(response.status, .badRequest)
    }

    // MARK: - Plain

    func testValidUsersCodeFlowPkcePlainWithoutVerifier() async throws {
        let code = try getCode(application: app, clientUUID: testAppIdent, challenge: codeVerifier, method: .plain)
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testValidUsersCodeFlowPkcePlainWrongVerifierMethod() async throws {
        let code = try getCode(application: app, clientUUID: testAppIdent, challenge: codeVerifier, method: .plain)
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value,
                    code_challenge_method: .sha256,
                    code_verifier: codeVerifier
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testValidUsersCodeFlowPkcePlainWrongVerifierString() async throws {
        let code = try getCode(application: app, clientUUID: testAppIdent, challenge: codeVerifier, method: .plain)
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value,
                    code_challenge_method: .plain,
                    code_verifier: "not-set-correctly"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testValidUsersCodeFlowPkcePlainCorrectVerifier() async throws {
        let code = try getCode(application: app, clientUUID: testAppIdent, challenge: codeVerifier, method: .plain)
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value,
                    code_challenge_method: .plain,
                    code_verifier: codeVerifier
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .ok)

        let accessToken = try response.content.decode(TokenResponse.self)
        XCTAssertEqual(accessToken.token_type, .Bearer)

        let jwt = accessToken.access_token
        let payload = try jwt_signer.verify(jwt, as: Payload.self)
        XCTAssertEqual(payload.user, "holger@mimimi.org")

        // There should be a request token, too
        XCTAssertNotNil(accessToken.refresh_token)
        XCTAssertEqual(accessToken.refresh_token?.count, Constants.TOKEN.LENGTH)
    }

    // MARK: - SHA265

    func testValidUsersCodeFlowPkceS265WithoutVerifier() async throws {
        let code = try getCode(
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
        )
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testValidUsersCodeFlowPkceS265WrongVerifierMethod() async throws {
        let code = try getCode(
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
        )
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value,
                    code_challenge_method: .plain,
                    code_verifier: codeVerifier
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testValidUsersCodeFlowPkceS265WrongVerifierString() async throws {
        let code = try getCode(
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
        )
        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value,
                    code_challenge_method: .sha256,
                    code_verifier: "not-set-correctly"
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        XCTAssertEqual(response.status, .forbidden)
    }

    func testValidUsersCodeFlowPkceS265CorrectVerifier() async throws {
        print("#### \(codeVerifierSHA256B64)")

        let code = try getCode(
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
        )

        let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
            let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value,
                    code_challenge_method: .sha256,
                    code_verifier: codeVerifier
            )
            try req.content.encode(tokenRequest, as: .json)
            req.headers.contentType = .json
        })
        print(response.body.string)
        XCTAssertEqual(response.status, .ok)

        let accessToken = try response.content.decode(TokenResponse.self)
        XCTAssertEqual(accessToken.token_type, .Bearer)

        let jwt = accessToken.access_token
        let payload = try jwt_signer.verify(jwt, as: Payload.self)
        XCTAssertEqual(payload.user, "holger@mimimi.org")

        // There should be a request token, too
        XCTAssertNotNil(accessToken.refresh_token)
        XCTAssertEqual(accessToken.refresh_token?.count, Constants.TOKEN.LENGTH)
    }
}
