import Foundation
import Testing
@testable import Uitsmijter_AuthServer

/// Tests for OpenidConfiguration
@Suite("OpenidConfiguration Tests")
// swiftlint:disable:next type_body_length
struct OpenidConfigurationTest {

    // MARK: - Basic Initialization Tests

    @Test("OpenidConfiguration init creates instance with all required fields")
    func initCreatesInstanceWithRequiredFields() {
        let config = OpenidConfiguration(
            issuer: "https://example.com",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"]
        )

        #expect(config.issuer == "https://example.com")
        #expect(config.authorization_endpoint == "https://example.com/authorize")
        #expect(config.token_endpoint == "https://example.com/token")
        #expect(config.jwks_uri == "https://example.com/.well-known/jwks.json")
        #expect(config.response_types_supported == ["code"])
        #expect(config.subject_types_supported == ["public"])
        #expect(config.id_token_signing_alg_values_supported == ["RS256"])
    }

    @Test("OpenidConfiguration with optional fields")
    func initWithOptionalFields() {
        let config = OpenidConfiguration(
            issuer: "https://example.com",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"],
            userinfo_endpoint: "https://example.com/userinfo",
            scopes_supported: ["openid", "profile", "email"],
            claims_supported: ["sub", "name", "email"],
            grant_types_supported: ["authorization_code", "refresh_token"]
        )

        #expect(config.userinfo_endpoint == "https://example.com/userinfo")
        #expect(config.scopes_supported == ["openid", "profile", "email"])
        #expect(config.claims_supported == ["sub", "name", "email"])
        #expect(config.grant_types_supported == ["authorization_code", "refresh_token"])
    }

    // MARK: - Codable Tests

    @Test("OpenidConfiguration is Codable")
    func isCodeable() throws {
        let config = OpenidConfiguration(
            issuer: "https://example.com/issuer",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"]
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        #expect(!data.isEmpty)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OpenidConfiguration.self, from: data)
        #expect(decoded.issuer == "https://example.com/issuer")
    }

    @Test("OpenidConfiguration encodes to expected JSON structure")
    func encodesToExpectedJSON() throws {
        let config = OpenidConfiguration(
            issuer: "https://auth.example.com",
            authorization_endpoint: "https://auth.example.com/authorize",
            token_endpoint: "https://auth.example.com/token",
            jwks_uri: "https://auth.example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"],
            scopes_supported: ["openid", "profile"]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(config)
        let jsonString = String(data: data, encoding: .utf8)

        #expect(jsonString?.contains("\"issuer\"") == true)
        #expect(jsonString?.contains("auth.example.com") == true)
        #expect(jsonString?.contains("\"authorization_endpoint\"") == true)
        #expect(jsonString?.contains("\"token_endpoint\"") == true)
        #expect(jsonString?.contains("\"jwks_uri\"") == true)
        #expect(jsonString?.contains("\"response_types_supported\"") == true)
        #expect(jsonString?.contains("\"subject_types_supported\"") == true)
        #expect(jsonString?.contains("\"id_token_signing_alg_values_supported\"") == true)
        #expect(jsonString?.contains("\"scopes_supported\"") == true)
    }

    @Test("OpenidConfiguration decodes from JSON with all required fields")
    func decodesFromJSONWithAllFields() throws {
        let json = """
        {
            "issuer": "https://issuer.example.org",
            "authorization_endpoint": "https://issuer.example.org/authorize",
            "token_endpoint": "https://issuer.example.org/token",
            "jwks_uri": "https://issuer.example.org/.well-known/jwks.json",
            "response_types_supported": ["code", "code id_token"],
            "subject_types_supported": ["public"],
            "id_token_signing_alg_values_supported": ["RS256", "ES256"],
            "scopes_supported": ["openid", "profile", "email"],
            "grant_types_supported": ["authorization_code", "refresh_token"]
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let config = try decoder.decode(OpenidConfiguration.self, from: data)

        #expect(config.issuer == "https://issuer.example.org")
        #expect(config.authorization_endpoint == "https://issuer.example.org/authorize")
        #expect(config.token_endpoint == "https://issuer.example.org/token")
        #expect(config.jwks_uri == "https://issuer.example.org/.well-known/jwks.json")
        #expect(config.response_types_supported == ["code", "code id_token"])
        #expect(config.subject_types_supported == ["public"])
        #expect(config.id_token_signing_alg_values_supported == ["RS256", "ES256"])
        #expect(config.scopes_supported == ["openid", "profile", "email"])
        #expect(config.grant_types_supported == ["authorization_code", "refresh_token"])
    }

    @Test("OpenidConfiguration handles PKCE code challenge methods")
    func handlesPKCECodeChallengeMethods() throws {
        let config = OpenidConfiguration(
            issuer: "https://example.com",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"],
            code_challenge_methods_supported: ["S256", "plain"]
        )

        #expect(config.code_challenge_methods_supported == ["S256", "plain"])

        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString?.contains("code_challenge_methods_supported") == true)
    }

    @Test("OpenidConfiguration with policy and terms URLs")
    func withPolicyAndTermsURLs() {
        let config = OpenidConfiguration(
            issuer: "https://example.com",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"],
            op_policy_uri: "https://example.com/privacy",
            op_tos_uri: "https://example.com/terms"
        )

        #expect(config.op_policy_uri == "https://example.com/privacy")
        #expect(config.op_tos_uri == "https://example.com/terms")
    }

    @Test("OpenidConfiguration with token endpoint auth methods")
    func withTokenEndpointAuthMethods() {
        let config = OpenidConfiguration(
            issuer: "https://example.com",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"],
            token_endpoint_auth_methods_supported: ["client_secret_post", "client_secret_basic", "none"]
        )

        #expect(config.token_endpoint_auth_methods_supported == ["client_secret_post", "client_secret_basic", "none"])
    }

    @Test("OpenidConfiguration with boolean flags")
    func withBooleanFlags() {
        let config = OpenidConfiguration(
            issuer: "https://example.com",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"],
            claims_parameter_supported: false,
            request_parameter_supported: false,
            request_uri_parameter_supported: false,
            require_request_uri_registration: false
        )

        #expect(config.claims_parameter_supported == false)
        #expect(config.request_parameter_supported == false)
        #expect(config.request_uri_parameter_supported == false)
        #expect(config.require_request_uri_registration == false)
    }

    // MARK: - Edge Cases

    @Test("OpenidConfiguration handles HTTPS scheme")
    func handlesHTTPSScheme() {
        let config = OpenidConfiguration(
            issuer: "https://secure.example.com",
            authorization_endpoint: "https://secure.example.com/authorize",
            token_endpoint: "https://secure.example.com/token",
            jwks_uri: "https://secure.example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"]
        )

        #expect(config.issuer.hasPrefix("https://"))
    }

    @Test("OpenidConfiguration preserves exact issuer URL")
    func preservesExactIssuerURL() {
        let issuerURL = "https://auth.server.com/realms/master"
        let config = OpenidConfiguration(
            issuer: issuerURL,
            authorization_endpoint: "\(issuerURL)/authorize",
            token_endpoint: "\(issuerURL)/token",
            jwks_uri: "\(issuerURL)/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"]
        )

        #expect(config.issuer == issuerURL)
    }

    @Test("OpenidConfiguration with complex issuer URL")
    func worksWithComplexIssuerURL() {
        let complexIssuer = "https://auth.example.com:8443/auth/realms/production"
        let config = OpenidConfiguration(
            issuer: complexIssuer,
            authorization_endpoint: "\(complexIssuer)/authorize",
            token_endpoint: "\(complexIssuer)/token",
            jwks_uri: "\(complexIssuer)/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"]
        )

        #expect(config.issuer == complexIssuer)
    }

    @Test("OpenidConfiguration roundtrip encode/decode preserves data")
    func roundtripPreservesData() throws {
        let original = OpenidConfiguration(
            issuer: "https://original.example.com",
            authorization_endpoint: "https://original.example.com/authorize",
            token_endpoint: "https://original.example.com/token",
            jwks_uri: "https://original.example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"],
            scopes_supported: ["openid", "profile", "email"],
            grant_types_supported: ["authorization_code", "refresh_token"],
            code_challenge_methods_supported: ["S256"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OpenidConfiguration.self, from: data)

        #expect(decoded.issuer == original.issuer)
        #expect(decoded.authorization_endpoint == original.authorization_endpoint)
        #expect(decoded.token_endpoint == original.token_endpoint)
        #expect(decoded.jwks_uri == original.jwks_uri)
        #expect(decoded.response_types_supported == original.response_types_supported)
        #expect(decoded.subject_types_supported == original.subject_types_supported)
        #expect(decoded.id_token_signing_alg_values_supported == original.id_token_signing_alg_values_supported)
        #expect(decoded.scopes_supported == original.scopes_supported)
        #expect(decoded.grant_types_supported == original.grant_types_supported)
        #expect(decoded.code_challenge_methods_supported == original.code_challenge_methods_supported)
    }

    @Test("OpenidConfiguration is Sendable")
    func isSendable() {
        let config = OpenidConfiguration(
            issuer: "https://example.com",
            authorization_endpoint: "https://example.com/authorize",
            token_endpoint: "https://example.com/token",
            jwks_uri: "https://example.com/.well-known/jwks.json",
            response_types_supported: ["code"],
            subject_types_supported: ["public"],
            id_token_signing_alg_values_supported: ["RS256"]
        )

        // This should compile without issues since OpenidConfiguration conforms to Sendable
        Task {
            _ = config.issuer
        }
    }
}
