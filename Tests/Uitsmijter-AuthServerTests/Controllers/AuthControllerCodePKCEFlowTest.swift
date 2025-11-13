import Foundation
import Testing
import VaporTesting
import CryptoSwift
@testable import Uitsmijter_AuthServer

/// OAuth 2.0 PKCE (Proof Key for Code Exchange) Flow Test Suite
///
/// Tests the complete PKCE flow as specified in RFC 7636.
/// Each test creates an isolated Vapor application via withApp(), ensuring no shared state.
/// https://www.oauth.com/oauth2-servers/pkce/
///
@Suite("Auth Controller Code PKCE Flow Test", .serialized)
// swiftlint:disable:next type_body_length
struct AuthControllerCodePKCEFlowTest {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    /// When the native app begins the authorization request, instead of immediately launching a
    /// browser, the client first creates what is known as a "code verifier". This is a cryptographically
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

    /// Once the app has generated the code verifier, it uses that to derive the code challenge. For devices
    /// that can perform a SHA256 hash, the code challenge is a Base64-URL-encoded string of the SHA256 hash of
    /// the code verifier. Clients that do not have the ability to perform a SHA256 hash are permitted to use the
    /// plain code verifier string as the challenge.
    @Test("Code verifier length validation")
    func testCodeVerifier() {
        #expect(codeVerifier.count >= 43)
        #expect(codeVerifier.count <= 128)
    }

    /// Characters of the Base64 alphabet can be grouped into four groups:
    /// Uppercase letters (indices 0-25): ABCDEFGHIJKLMNOPQRSTUVWXYZ
    /// Lowercase letters (indices 26-51): abcdefghijklmnopqrstuvwxyz
    /// Digits (indices 52-61): 0123456789
    /// Special symbols (indices 62-63):
    @Test("Code verifier SHA256 format validation")
    func testCodeVerifierH256() throws {
        _ = try codeVerifierSHA256B64.groups(regex: "^[A-Za-z0-9+-_]+$")
    }

    @Test("Valid users code flow PKCE plain missing code challenge")
    func testValidUsersCodeFlowPacePlainMissingCodeChallenge() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            // get the tenant to save the id into the Payload
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            let response = try await app.sendRequest(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123&"
                    + "&code_challenge_method=plain",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                }
            )
            #expect(response.status == .badRequest)
        }
    }

    // MARK: - Plain

    @Test("Valid users code flow PKCE plain without verifier")
    func testValidUsersCodeFlowPkcePlainWithoutVerifier() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(
                in: app.entityStorage,
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifier,
                method: .plain
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .forbidden)
        }
    }

    @Test("Valid users code flow PKCE plain wrong verifier method")
    func testValidUsersCodeFlowPkcePlainWrongVerifierMethod() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(
                in: app.entityStorage,
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifier,
                method: .plain
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .forbidden)
        }
    }

    @Test("Valid users code flow PKCE plain wrong verifier string")
    func testValidUsersCodeFlowPkcePlainWrongVerifierString() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(
                in: app.entityStorage,
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifier,
                method: .plain
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .forbidden)
        }
    }

    @Test("Valid users code flow PKCE plain correct verifier")
    func testValidUsersCodeFlowPkcePlainCorrectVerifier() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(
                in: app.entityStorage,
                application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifier,
                method: .plain
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .ok)

            let accessToken = try response.content.decode(TokenResponse.self)
            #expect(accessToken.token_type == .Bearer)

            let jwt = accessToken.access_token
            let payload = try await SignerManager.shared.verify(jwt, as: Payload.self)
            #expect(payload.user == "holger@mimimi.org")

            // There should be a request token, too
            #expect(accessToken.refresh_token != nil)
            #expect(accessToken.refresh_token?.count == Constants.TOKEN.LENGTH)
        }
    }

    // MARK: - SHA265

    @Test("Valid users code flow PKCE S265 without verifier")
    func testValidUsersCodeFlowPkceS265WithoutVerifier() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(in: app.entityStorage, application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .forbidden)
        }
    }

    @Test("Valid users code flow PKCE S265 wrong verifier method")
    func testValidUsersCodeFlowPkceS265WrongVerifierMethod() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(in: app.entityStorage, application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .forbidden)
        }
    }

    @Test("Valid users code flow PKCE S265 wrong verifier string")
    func testValidUsersCodeFlowPkceS265WrongVerifierString() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(in: app.entityStorage, application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .forbidden)
        }
    }

    @Test("Valid users code flow PKCE S265 correct verifier")
    func testValidUsersCodeFlowPkceS265CorrectVerifier() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            print("#### \(codeVerifierSHA256B64)")

            let code = try await getCode(in: app.entityStorage, application: app,
                clientUUID: testAppIdent,
                challenge: codeVerifierSHA256B64,
                method: .sha256
            )

            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
            #expect(response.status == .ok)

            let accessToken = try response.content.decode(TokenResponse.self)
            #expect(accessToken.token_type == .Bearer)

            let jwt = accessToken.access_token
            let payload = try await SignerManager.shared.verify(jwt, as: Payload.self)
            #expect(payload.user == "holger@mimimi.org")

            // There should be a request token, too
            #expect(accessToken.refresh_token != nil)
            #expect(accessToken.refresh_token?.count == Constants.TOKEN.LENGTH)
        }
    }
}
