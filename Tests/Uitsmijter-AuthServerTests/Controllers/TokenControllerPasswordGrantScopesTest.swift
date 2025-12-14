import Foundation
import Testing
import VaporTesting
import CryptoSwift
@testable import Uitsmijter_AuthServer

///
///  Password Grant Flow Scope Filtering Test
///
///  ┌─────┐
///  │  password grant  │
///  └─────┘
///   access (requested)
///         │
///         │    allowedRequestScopes:
///         │       access
///         │──────────────────────▶
///                                               access (filtered)
///                                                ┌────────┐
///                                                │   user provider    │
///                                                └────────┘
///                                               user:list (from provider)
///         ◀───────────────────────│
///         │
///         │   allowedProviderScopes:
///         │       user:*
///         │
///   access (requested)
///   user:list (from provider)
///
/// Tests that password grant properly filters both client-requested scopes and provider-pushed scopes
///

@Suite("Token Controller Password Grant Scopes Test", .serialized)
struct TokenControllerPasswordGrantScopesTest {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    @MainActor
    func setupEntities(app: Application) async throws {
        app.entityStorage.tenants.removeAll()
        app.entityStorage.clients.removeAll()

        var tenantConfig = TenantSpec(
            hosts: ["127.0.0.1",
                    "example.com",
                    "localhost.localdomain",
                    "localhost"],
            jwt_algorithm: "RS256"  // RS256 for consistency with other tests
        )
        tenantConfig.providers.append(
            """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    scopes = [];
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.password);
                         this.isLoggedIn = true;
                         this.scopes = ["user:list", "admin:write"]  // Provider pushes multiple scopes
                         commit({
                            subject: credentials.username.replace(/@/g, "_")
                         });
                    }

                    // Getter
                    get canLogin() {
                       return this.isLoggedIn;
                    }

                    get role(){
                        return "test-user"
                    }

                    get scopes(){
                        return this.scopes  // Returns ["user:list", "admin:write"]
                    }

                    get userProfile() {
                       return {
                          name: "Test User Password Grant",
                          role: "user"
                       };
                    }
                 }
                """
        )
        let tenant = Tenant(name: "Password Grant Scope Test Tenant", config: tenantConfig)

        let (inserted, _) = app.entityStorage.tenants.insert(tenant)
        #expect(inserted)

        let client = Client(
            name: "Password Grant Test Client",
            config: ClientSpec(
                ident: testAppIdent,
                tenantname: tenant.name,
                redirect_urls: [
                    "http://localhost:?([0-9]+)?", "http://example.com"
                ],
                grant_types: ["password", "refresh_token"],
                scopes: ["access", "openid"],  // Only allow "access" and "openid" scopes
                allowedProviderScopes: [
                    "user:*"  // Allow user:* from provider (blocks admin:write)
                ],
                referrers: [
                    ".*"
                ]
            )
        )
        app.entityStorage.clients = [client]
    }

    @Test("Password grant filters both requested and provider scopes")
    func testPasswordGrantWithScopeFiltering() async throws {
        try await withApp(configure: configure) { app in
            try await setupEntities(app: app)

            // Request token via password grant with "access openid admin:delete" scopes
            // Provider will push "user:list" and "admin:write"
            // Expected result: "access openid user:list"
            //   - "access" and "openid" are allowed by client.config.scopes
            //   - "admin:delete" is filtered out (not in client.config.scopes)
            //   - "user:list" is allowed by allowedProviderScopes pattern "user:*"
            //   - "admin:write" is filtered out (doesn't match "user:*" pattern)

            let tokenResponse = try await app.sendRequest(.POST, "/token", beforeRequest: {
                @Sendable req async throws in
                let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: "access openid admin:delete",  // Request 3 scopes, 1 should be filtered
                    username: "test_user",
                    password: "test_password"
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })

            #expect(tokenResponse.status == .ok)

            let tokenResponseBody = try decoder.decode(TokenResponse.self, from: tokenResponse.body)
            #expect(tokenResponseBody.access_token.isEmpty == false)

            // Verify TokenResponse has the correct filtered scope string
            let expectedScopes = ["access", "openid", "user:list"].sorted()
            let actualScopes = (tokenResponseBody.scope ?? "").split(separator: " ").map { String($0) }.sorted()
            #expect(actualScopes == expectedScopes, "TokenResponse scope should contain only filtered scopes")

            // Decode JWT payload to verify scopes in the token itself
            let jwtParts = tokenResponseBody.access_token.split(separator: ".")
            #expect(jwtParts.count == 3, "JWT should have 3 parts")

            let payloadBase64 = String(jwtParts[1])
            let payloadData = Data(base64Encoded: base64UrlToBase64(payloadBase64))
            #expect(payloadData != nil, "Should decode JWT payload")

            if let payloadData = payloadData {
                struct JWTPayload: Codable {
                    let scope: String
                    let sub: String
                    let aud: String
                    let tenant: String
                }

                let payload = try decoder.decode(JWTPayload.self, from: payloadData)

                // Verify the access token payload contains the expected filtered scopes
                let tokenScopes = payload.scope.split(separator: " ").map { String($0) }.sorted()
                #expect(tokenScopes == expectedScopes, "JWT payload should contain only filtered scopes")

                // Verify requested scopes that should be present
                #expect(payload.scope.contains("access"), "Should contain 'access' from client request")
                #expect(payload.scope.contains("openid"), "Should contain 'openid' from client request")
                #expect(payload.scope.contains("user:list"), "Should contain 'user:list' from provider")

                // Verify filtered scopes that should NOT be present
                #expect(!payload.scope.contains("admin:delete"), "Should NOT contain 'admin:delete' (filtered by client.config.scopes)")
                #expect(!payload.scope.contains("admin:write"), "Should NOT contain 'admin:write' (filtered by allowedProviderScopes)")

                #expect(payload.tenant == "Password Grant Scope Test Tenant", "Tenant should match")
                #expect(payload.sub == "test_user", "Subject should match")
            }
        }
    }

    @MainActor
    func setupEntitiesWithoutProviderRestrictions(app: Application) async throws {
        app.entityStorage.tenants.removeAll()
        app.entityStorage.clients.removeAll()

        // Create tenant with provider that pushes scopes
        var tenantConfig = TenantSpec(
            hosts: ["127.0.0.1", "localhost"],
            jwt_algorithm: "RS256"
        )
        tenantConfig.providers.append(
            """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    constructor(credentials) {
                         this.isLoggedIn = true;
                         commit({ subject: credentials.username });
                    }
                    get canLogin() { return this.isLoggedIn; }
                    get role() { return "user"; }
                    get scopes() { return ["provider:scope1", "provider:scope2"]; }
                    get userProfile() { return { name: "Test User" }; }
                 }
                """
        )
        let tenant = Tenant(name: "Test Tenant", config: tenantConfig)
        app.entityStorage.tenants.insert(tenant)

        // Create client WITHOUT allowedProviderScopes
        let client = Client(
            name: "Test Client",
            config: ClientSpec(
                ident: testAppIdent,
                tenantname: tenant.name,
                redirect_urls: ["http://localhost"],
                grant_types: ["password"],
                scopes: ["access"],
                allowedProviderScopes: nil,  // NO provider scope restrictions
                referrers: [".*"]
            )
        )
        app.entityStorage.clients = [client]
    }

    @Test("Password grant without allowedProviderScopes allows all provider scopes")
    func testPasswordGrantWithoutProviderScopeRestrictions() async throws {
        try await withApp(configure: configure) { app in
            try await setupEntitiesWithoutProviderRestrictions(app: app)

            let tokenResponse = try await app.sendRequest(.POST, "/token", beforeRequest: {
                @Sendable req async throws in
                let tokenRequest = PasswordTokenRequest(
                    grant_type: .password,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: "access",
                    username: "test_user",
                    password: "test_password"
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })

            #expect(tokenResponse.status == .ok)

            let tokenResponseBody = try decoder.decode(TokenResponse.self, from: tokenResponse.body)

            // When no allowedProviderScopes is set, all provider scopes should be included
            let expectedScopes = ["access", "provider:scope1", "provider:scope2"].sorted()
            let actualScopes = (tokenResponseBody.scope ?? "").split(separator: " ").map { String($0) }.sorted()
            #expect(actualScopes == expectedScopes, "Should include all provider scopes when no restrictions configured")
        }
    }

    /// Helper function to convert base64url to standard base64
    private func base64UrlToBase64(_ base64Url: String) -> String {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return base64
    }
}
