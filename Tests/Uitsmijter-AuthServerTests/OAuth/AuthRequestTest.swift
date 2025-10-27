import Foundation
@testable import Uitsmijter_AuthServer
import Testing

/// Tests for OAuth2 Authorization Request types
@Suite("AuthRequest Tests")
// swiftlint:disable type_body_length
struct AuthRequestTest {

    // MARK: - ResponseType Tests

    @Test("ResponseType code case exists")
    func responseTypeCodeExists() {
        let responseType = ResponseType.code
        #expect(responseType == .code)
    }

    @Test("ResponseType has correct raw value")
    func responseTypeRawValue() {
        #expect(ResponseType.code.rawValue == "code")
    }

    @Test("ResponseType is Codable")
    func responseTypeIsCodable() throws {
        let responseType = ResponseType.code
        let data = try JSONEncoder().encode(responseType)
        let decoded = try JSONDecoder().decode(ResponseType.self, from: data)
        #expect(decoded == responseType)
    }

    @Test("ResponseType is Sendable")
    func responseTypeIsSendable() async {
        let responseType = ResponseType.code
        await Task {
            #expect(responseType == .code)
        }.value
    }

    // MARK: - CodeChallengeMethod Tests

    @Test("CodeChallengeMethod has all cases")
    func codeChallengeMethodCases() {
        #expect(CodeChallengeMethod.none.rawValue == "none")
        #expect(CodeChallengeMethod.plain.rawValue == "plain")
        #expect(CodeChallengeMethod.sha256.rawValue == "S256")
    }

    @Test("CodeChallengeMethod is Codable")
    func codeChallengeMethodIsCodable() throws {
        let method = CodeChallengeMethod.sha256
        let data = try JSONEncoder().encode(method)
        let decoded = try JSONDecoder().decode(CodeChallengeMethod.self, from: data)
        #expect(decoded == method)
    }

    @Test("CodeChallengeMethod is Sendable")
    func codeChallengeMethodIsSendable() async {
        let method = CodeChallengeMethod.sha256
        await Task {
            #expect(method == .sha256)
        }.value
    }

    // MARK: - ScopesProtocol Tests

    @Test("ScopesProtocol can be implemented")
    func scopesProtocolImplementation() {
        struct TestScopes: ScopesProtocol {
            let scope: String? = "read write"
        }

        let testScopes = TestScopes()
        #expect(testScopes.scope == "read write")
    }

    // MARK: - AuthRequest Tests

    @Test("AuthRequest initializes with all parameters")
    func authRequestInitialization() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback"))

        let request = AuthRequest(
            response_type: .code,
            client_id: "test-client-id",
            client_secret: "test-secret",
            redirect_uri: redirectUri,
            scope: "read write",
            state: "test-state"
        )

        #expect(request.response_type == .code)
        #expect(request.client_id == "test-client-id")
        #expect(request.client_secret == "test-secret")
        #expect(request.redirect_uri == redirectUri)
        #expect(request.scope == "read write")
        #expect(request.state == "test-state")
    }

    @Test("AuthRequest initializes with default values")
    func authRequestDefaults() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback"))

        let request = AuthRequest(
            response_type: .code,
            client_id: "test-client-id",
            redirect_uri: redirectUri,
            state: "test-state"
        )

        #expect(request.client_secret == nil)
        #expect(request.scope == nil)
    }

    @Test("AuthRequest is Codable")
    func authRequestIsCodable() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback"))

        let request = AuthRequest(
            response_type: .code,
            client_id: "test-client-id",
            redirect_uri: redirectUri,
            scope: "read",
            state: "state123"
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(AuthRequest.self, from: data)

        #expect(decoded.response_type == request.response_type)
        #expect(decoded.client_id == request.client_id)
        #expect(decoded.redirect_uri == request.redirect_uri)
        #expect(decoded.scope == request.scope)
        #expect(decoded.state == request.state)
    }

    @Test("AuthRequest redirectPath extracts path from URI")
    func authRequestRedirectPath() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback/oauth"))

        let request = AuthRequest(
            response_type: .code,
            client_id: "client",
            redirect_uri: redirectUri,
            state: "state"
        )

        #expect(request.redirectPath == "/callback/oauth")
    }

    @Test("AuthRequest implements all required protocols")
    func authRequestImplementsProtocols() throws {
        let redirectUri = try #require(URL(string: "https://example.com"))

        let request = AuthRequest(
            response_type: .code,
            client_id: "client-id",
            redirect_uri: redirectUri,
            state: "state"
        )

        // ClientIdProtocol
        #expect(request.client_id == "client-id")

        // RedirectUriProtocol
        #expect(request.redirect_uri == redirectUri)

        // ScopesProtocol
        #expect(request.scope == nil)
    }

    // MARK: - AuthRequestPKCE Tests

    @Test("AuthRequestPKCE initializes with all parameters")
    func authRequestPKCEInitialization() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback"))

        let request = AuthRequestPKCE(
            response_type: .code,
            client_id: "test-client-id",
            client_secret: "test-secret",
            redirect_uri: redirectUri,
            scope: "read write",
            state: "test-state",
            code_challenge: "E9Melhoa20wvFrEMTJguCHaoeK1t8URWbuGjSstw-CM",
            code_challenge_method: .sha256
        )

        #expect(request.response_type == .code)
        #expect(request.client_id == "test-client-id")
        #expect(request.client_secret == "test-secret")
        #expect(request.redirect_uri == redirectUri)
        #expect(request.scope == "read write")
        #expect(request.state == "test-state")
        #expect(request.code_challenge == "E9Melhoa20wvFrEMTJguCHaoeK1t8URWbuGjSstw-CM")
        #expect(request.code_challenge_method == .sha256)
    }

    @Test("AuthRequestPKCE initializes with default values")
    func authRequestPKCEDefaults() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback"))

        let request = AuthRequestPKCE(
            response_type: .code,
            client_id: "client-id",
            redirect_uri: redirectUri,
            state: "state",
            code_challenge: "challenge",
            code_challenge_method: .plain
        )

        #expect(request.client_secret == nil)
        #expect(request.scope == nil)
    }

    @Test("AuthRequestPKCE is Codable")
    func authRequestPKCEIsCodable() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback"))

        let request = AuthRequestPKCE(
            response_type: .code,
            client_id: "client-id",
            redirect_uri: redirectUri,
            state: "state123",
            code_challenge: "challenge123",
            code_challenge_method: .sha256
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(AuthRequestPKCE.self, from: data)

        #expect(decoded.response_type == request.response_type)
        #expect(decoded.client_id == request.client_id)
        #expect(decoded.redirect_uri == request.redirect_uri)
        #expect(decoded.state == request.state)
        #expect(decoded.code_challenge == request.code_challenge)
        #expect(decoded.code_challenge_method == request.code_challenge_method)
    }

    @Test("AuthRequestPKCE with different challenge methods")
    func authRequestPKCEWithDifferentMethods() throws {
        let redirectUri = try #require(URL(string: "https://example.com/callback"))

        let plainRequest = AuthRequestPKCE(
            response_type: .code,
            client_id: "client",
            redirect_uri: redirectUri,
            state: "state",
            code_challenge: "plain-challenge",
            code_challenge_method: .plain
        )
        #expect(plainRequest.code_challenge_method == .plain)

        let sha256Request = AuthRequestPKCE(
            response_type: .code,
            client_id: "client",
            redirect_uri: redirectUri,
            state: "state",
            code_challenge: "hashed-challenge",
            code_challenge_method: .sha256
        )
        #expect(sha256Request.code_challenge_method == .sha256)
    }

    // MARK: - AuthRequests Enum Tests

    @Test("AuthRequests wraps insecure request")
    func authRequestsWrapsInsecure() throws {
        let redirectUri = try #require(URL(string: "https://example.com"))

        let request = AuthRequest(
            response_type: .code,
            client_id: "client",
            redirect_uri: redirectUri,
            state: "state"
        )

        let wrapped = AuthRequests.insecure(request)

        switch wrapped {
        case .insecure(let unwrapped):
            #expect(unwrapped.client_id == "client")
        case .pkce:
            Issue.record("Expected insecure case")
        }
    }

    @Test("AuthRequests wraps PKCE request")
    func authRequestsWrapsPKCE() throws {
        let redirectUri = try #require(URL(string: "https://example.com"))

        let request = AuthRequestPKCE(
            response_type: .code,
            client_id: "client",
            redirect_uri: redirectUri,
            state: "state",
            code_challenge: "challenge",
            code_challenge_method: .sha256
        )

        let wrapped = AuthRequests.pkce(request)

        switch wrapped {
        case .insecure:
            Issue.record("Expected PKCE case")
        case .pkce(let unwrapped):
            #expect(unwrapped.client_id == "client")
            #expect(unwrapped.code_challenge == "challenge")
        }
    }

    @Test("AuthRequests is Sendable")
    func authRequestsIsSendable() async throws {
        let redirectUri = try #require(URL(string: "https://example.com"))

        let request = AuthRequest(
            response_type: .code,
            client_id: "client",
            redirect_uri: redirectUri,
            state: "state"
        )

        let wrapped = AuthRequests.insecure(request)

        await Task {
            switch wrapped {
            case .insecure(let unwrapped):
                #expect(unwrapped.client_id == "client")
            case .pkce:
                Issue.record("Expected insecure case")
            }
        }.value
    }
}
// swiftlint:enable type_body_length
