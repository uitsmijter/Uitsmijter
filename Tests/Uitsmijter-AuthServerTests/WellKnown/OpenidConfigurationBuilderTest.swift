import Foundation
import Testing
import Vapor
@testable import Uitsmijter_AuthServer

/// Tests for OpenidConfigurationBuilder
@Suite("OpenidConfigurationBuilder Tests")
@MainActor
// swiftlint:disable:next type_body_length
struct OpenidConfigurationBuilderTest {

    // MARK: - Helper Methods

    func createTestApp() async throws -> Application {
        let app = try await Application.make(.testing)
        app.entityStorage.tenants.removeAll()
        app.entityStorage.clients.removeAll()
        return app
    }

    func createTestTenant(name: String, hosts: [String], informations: TenantInformations? = nil) -> Tenant {
        Tenant(
            name: name,
            config: TenantSpec(
                hosts: hosts,
                informations: informations
            )
        )
    }

    func createTestClient(
        name: String,
        tenantName: String,
        scopes: [String]? = nil,
        grantTypes: [String]? = nil
    ) -> UitsmijterClient {
        UitsmijterClient(
            name: name,
            config: ClientSpec(
                ident: UUID(),
                tenantname: tenantName,
                redirect_urls: [".*\\.example\\.com"],
                grant_types: grantTypes,
                scopes: scopes
            )
        )
    }

    func createMockRequest(app: Application, host: String, scheme: String = "https") -> Request {
        var headers = HTTPHeaders()
        headers.add(name: "Host", value: host)
        headers.add(name: "X-Forwarded-Proto", value: scheme)

        return Request(
            application: app,
            method: .GET,
            url: URI(string: "/.well-known/openid-configuration"),
            headers: headers,
            on: app.eventLoopGroup.any()
        )
    }

    // MARK: - Basic Builder Tests

    @Test("Builder creates configuration with required fields")
    func builderCreatesConfigurationWithRequiredFields() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "TestTenant", hosts: ["auth.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "auth.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        #expect(config.issuer == "https://auth.example.com")
        #expect(config.authorization_endpoint == "https://auth.example.com/authorize")
        #expect(config.token_endpoint == "https://auth.example.com/token")
        #expect(config.jwks_uri == "https://auth.example.com/.well-known/jwks.json")
        #expect(config.response_types_supported == ["code"])
        #expect(config.subject_types_supported == ["public"])
        #expect(config.id_token_signing_alg_values_supported == ["RS256"])
    }

    @Test("Builder uses correct scheme from request")
    func builderUsesCorrectSchemeFromRequest() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "TestTenant", hosts: ["example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let httpRequest = createMockRequest(app: app, host: "example.com", scheme: "http")

        let config = await builder.build(for: tenant, request: httpRequest, storage: app.entityStorage)

        #expect(config.issuer.hasPrefix("http://"))
    }

    @Test("Builder includes default scopes")
    func builderIncludesDefaultScopes() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "TestTenant", hosts: ["example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        #expect(config.scopes_supported?.contains("openid") == true)
        #expect(config.scopes_supported?.contains("profile") == true)
        #expect(config.scopes_supported?.contains("email") == true)
    }

    @Test("Builder includes default grant types")
    func builderIncludesDefaultGrantTypes() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "TestTenant", hosts: ["example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        #expect(config.grant_types_supported?.contains("authorization_code") == true)
        #expect(config.grant_types_supported?.contains("refresh_token") == true)
    }

    // MARK: - Multi-Tenant Tests

    @Test("Builder aggregates scopes from multiple clients")
    func builderAggregatesScopesFromMultipleClients() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "MultiScopeTenant", hosts: ["multi.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let client1 = createTestClient(
            name: "Client1",
            tenantName: "MultiScopeTenant",
            scopes: ["read", "write"]
        )
        let client2 = createTestClient(
            name: "Client2",
            tenantName: "MultiScopeTenant",
            scopes: ["admin", "delete"]
        )

        app.entityStorage.clients.append(client1)
        app.entityStorage.clients.append(client2)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "multi.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        // Should contain default scopes plus client-specific scopes
        #expect(config.scopes_supported?.contains("openid") == true)
        #expect(config.scopes_supported?.contains("profile") == true)
        #expect(config.scopes_supported?.contains("email") == true)
        #expect(config.scopes_supported?.contains("read") == true)
        #expect(config.scopes_supported?.contains("write") == true)
        #expect(config.scopes_supported?.contains("admin") == true)
        #expect(config.scopes_supported?.contains("delete") == true)
    }

    @Test("Builder aggregates grant types from multiple clients")
    func builderAggregatesGrantTypesFromMultipleClients() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "MultiGrantTenant", hosts: ["grant.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let client1 = createTestClient(
            name: "Client1",
            tenantName: "MultiGrantTenant",
            grantTypes: ["implicit"]
        )
        let client2 = createTestClient(
            name: "Client2",
            tenantName: "MultiGrantTenant",
            grantTypes: ["client_credentials"]
        )

        app.entityStorage.clients.append(client1)
        app.entityStorage.clients.append(client2)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "grant.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        // Should contain default grant types plus client-specific grant types
        #expect(config.grant_types_supported?.contains("authorization_code") == true)
        #expect(config.grant_types_supported?.contains("refresh_token") == true)
        #expect(config.grant_types_supported?.contains("implicit") == true)
        #expect(config.grant_types_supported?.contains("client_credentials") == true)
    }

    @Test("Builder handles tenant with no clients")
    func builderHandlesTenantWithNoClients() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "NoClientsTenant", hosts: ["empty.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "empty.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        // Should still return default scopes and grant types
        #expect(config.scopes_supported?.contains("openid") == true)
        #expect(config.grant_types_supported?.contains("authorization_code") == true)
    }

    @Test("Builder creates distinct configurations for different tenants")
    func builderCreatesDistinctConfigurationsForDifferentTenants() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant1 = createTestTenant(name: "Tenant1", hosts: ["tenant1.example.com"])
        let tenant2 = createTestTenant(name: "Tenant2", hosts: ["tenant2.example.com"])

        app.entityStorage.tenants.insert(tenant1)
        app.entityStorage.tenants.insert(tenant2)

        let client1 = createTestClient(
            name: "Client1",
            tenantName: "Tenant1",
            scopes: ["tenant1-scope"]
        )
        let client2 = createTestClient(
            name: "Client2",
            tenantName: "Tenant2",
            scopes: ["tenant2-scope"]
        )

        app.entityStorage.clients.append(client1)
        app.entityStorage.clients.append(client2)

        let builder = OpenidConfigurationBuilder()
        let request1 = createMockRequest(app: app, host: "tenant1.example.com")
        let request2 = createMockRequest(app: app, host: "tenant2.example.com")

        let config1 = await builder.build(for: tenant1, request: request1, storage: app.entityStorage)
        let config2 = await builder.build(for: tenant2, request: request2, storage: app.entityStorage)

        // Different issuers
        #expect(config1.issuer == "https://tenant1.example.com")
        #expect(config2.issuer == "https://tenant2.example.com")

        // Different scopes
        #expect(config1.scopes_supported?.contains("tenant1-scope") == true)
        #expect(config1.scopes_supported?.contains("tenant2-scope") == false)

        #expect(config2.scopes_supported?.contains("tenant2-scope") == true)
        #expect(config2.scopes_supported?.contains("tenant1-scope") == false)
    }

    // MARK: - Tenant Information Tests

    @Test("Builder includes tenant privacy URL as policy URI")
    func builderIncludesTenantPrivacyURL() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let informations = TenantInformations(
            imprint_url: "https://example.com/imprint",
            privacy_url: "https://example.com/privacy",
            register_url: "https://example.com/register"
        )

        let tenant = createTestTenant(
            name: "InfoTenant",
            hosts: ["info.example.com"],
            informations: informations
        )
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "info.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        #expect(config.op_policy_uri == "https://example.com/privacy")
        #expect(config.service_documentation == "https://example.com/imprint")
    }

    @Test("Builder handles tenant without informations")
    func builderHandlesTenantWithoutInformations() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "NoInfoTenant", hosts: ["noinfo.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "noinfo.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        #expect(config.op_policy_uri == nil)
        #expect(config.service_documentation == nil)
    }

    // MARK: - Endpoint Construction Tests

    @Test("Builder constructs correct endpoint URLs")
    func builderConstructsCorrectEndpointURLs() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "EndpointTenant", hosts: ["auth.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "auth.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        let expectedIssuer = "https://auth.example.com"
        #expect(config.issuer == expectedIssuer)
        #expect(config.authorization_endpoint == "\(expectedIssuer)/authorize")
        #expect(config.token_endpoint == "\(expectedIssuer)/token")
        #expect(config.jwks_uri == "\(expectedIssuer)/.well-known/jwks.json")
        #expect(config.userinfo_endpoint == "\(expectedIssuer)/token/info")
    }

    @Test("Builder includes PKCE code challenge methods")
    func builderIncludesPKCECodeChallengeMethods() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "PKCETenant", hosts: ["pkce.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "pkce.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        #expect(config.code_challenge_methods_supported?.contains("S256") == true)
        #expect(config.code_challenge_methods_supported?.contains("plain") == true)
    }

    @Test("Builder includes supported claims")
    func builderIncludesSupportedClaims() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "ClaimsTenant", hosts: ["claims.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "claims.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        #expect(config.claims_supported?.contains("sub") == true)
        #expect(config.claims_supported?.contains("iss") == true)
        #expect(config.claims_supported?.contains("aud") == true)
        #expect(config.claims_supported?.contains("exp") == true)
        #expect(config.claims_supported?.contains("iat") == true)
        #expect(config.claims_supported?.contains("name") == true)
        #expect(config.claims_supported?.contains("email") == true)
        #expect(config.claims_supported?.contains("tenant") == true)
    }

    @Test("Builder includes end session endpoint")
    func builderIncludesEndSessionEndpoint() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "LogoutTenant", hosts: ["logout.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "logout.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        let expectedEndSessionEndpoint = "https://logout.example.com/logout"
        #expect(config.end_session_endpoint == expectedEndSessionEndpoint)
    }

    // MARK: - Deduplication Tests

    @Test("Builder deduplicates scopes from multiple clients")
    func builderDeduplicatesScopes() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "DedupeTenant", hosts: ["dedupe.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let client1 = createTestClient(
            name: "Client1",
            tenantName: "DedupeTenant",
            scopes: ["read", "write", "openid"]
        )
        let client2 = createTestClient(
            name: "Client2",
            tenantName: "DedupeTenant",
            scopes: ["read", "admin", "openid"]
        )

        app.entityStorage.clients.append(client1)
        app.entityStorage.clients.append(client2)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "dedupe.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        // Count occurrences - each scope should appear only once
        let scopes = config.scopes_supported ?? []
        let readCount = scopes.filter { $0 == "read" }.count
        let openidCount = scopes.filter { $0 == "openid" }.count

        #expect(readCount == 1)
        #expect(openidCount == 1)
        #expect(scopes.contains("write"))
        #expect(scopes.contains("admin"))
    }

    @Test("Builder sorts scopes alphabetically")
    func builderSortsScopesAlphabetically() async throws {
        let app = try await createTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let tenant = createTestTenant(name: "SortTenant", hosts: ["sort.example.com"])
        app.entityStorage.tenants.insert(tenant)

        let client = createTestClient(
            name: "Client",
            tenantName: "SortTenant",
            scopes: ["zebra", "alpha", "beta"]
        )

        app.entityStorage.clients.append(client)

        let builder = OpenidConfigurationBuilder()
        let request = createMockRequest(app: app, host: "sort.example.com")

        let config = await builder.build(for: tenant, request: request, storage: app.entityStorage)

        let scopes = config.scopes_supported ?? []

        // Verify alphabetical order
        for i in 0..<scopes.count - 1 {
            #expect(scopes[i] < scopes[i + 1])
        }
    }
}
