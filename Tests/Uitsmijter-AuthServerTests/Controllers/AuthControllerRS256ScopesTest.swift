import Foundation
import Testing
import VaporTesting
import CryptoSwift
@testable import Uitsmijter_AuthServer

///
///  ┌─────┐
///  │    client     │
///  └─────┘
///   access (requested)
///         │
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
/// RS256 Tenant Token can be verified with public key from .well-known/jwks.json
///

// Tests that RS256 tokens with scope enrichment can be verified using JWKS public key
@Suite("Auth Controller RS256 Scopes Test", .serialized)
struct AuthControllerRS256ScopesTest {
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
            jwt_algorithm: "RS256"  // RS256 signing for public key verification
        )
        tenantConfig.providers.append(
            """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    scopes = [];
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.password);
                         this.isLoggedIn = true;
                         this.scopes = ["user:list"]
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
                        return this.scopes
                    }

                    get userProfile() {
                       return {
                          name: "Test User RS256",
                          role: "user"
                       };
                    }
                 }
                """
        )
        let tenant = Tenant(name: "RS256 Scope Test Tenant", config: tenantConfig)

        let (inserted, _) = app.entityStorage.tenants.insert(tenant)
        #expect(inserted)

        let client = Client(
            name: "RS256 Test Client",
            config: ClientSpec(
                ident: testAppIdent,
                tenantname: tenant.name,
                redirect_urls: [
                    "http://localhost:?([0-9]+)?", "http://example.com"
                ],
                grant_types: ["password",
                              "authorization_code",
                              "refresh_token"],
                scopes: ["access"],  // Only allow "access" scope
                allowedProviderScopes: [
                    "user:*"  // Allow user:* from provider
                ],
                referrers: [
                    ".*"
                ]
            )
        )
        app.entityStorage.clients = [client]
    }

    @Test("RS256 token with scope enrichment from provider")
    func testRS256TokenWithScopeEnrichment() async throws {
        try await withApp(configure: configure) { app in
            try await setupEntities(app: app)

            // 1. Request Code
            // -----------------------------------
            let state = String.random(length: 8)
            let authorizeUrl = "/authorize"
                + "?response_type=code"
                + "&client_id=\(testAppIdent)"
                + "&redirect_uri=http://localhost:9090"
                + "&scope=access"  // Request "access" scope
                + "&state=\(state)"

            let responseAuthorize = try await app.sendRequest(
                .GET,
                authorizeUrl,
                headers: ["Content-Type": "application/json", "referer": "http://localhost:9090"]
            )

            #expect(responseAuthorize.status == .unauthorized)
            #expect(responseAuthorize.body.string.contains("<body"))
            #expect(responseAuthorize.body.string.contains("</html>"))
            #expect(responseAuthorize.body.string.contains("login"))

            // Check scopes in login form
            let scopeFormFiledValue: [String] = try {
                let value = try responseAuthorize.body.string.groups(
                    regex: "input\\s+type=\"hidden\"\\s+name=\"scope\"\\s+value=\"(.*)\""
                )
                if value.count != 2 {
                    return []
                }
                return value[1].split(separator: "+").map({String($0)}).sorted()
            }()

            #expect(scopeFormFiledValue.contains("access"))
            #expect(scopeFormFiledValue.count == 1)

            let testServerAddress = "http://\(app.http.server.configuration.hostname):\(app.http.server.configuration.port)"
            let locationString = "\(testServerAddress)\(authorizeUrl.replacingOccurrences(of: "&", with: "&amp;"))"

            // 2. Login
            // -----------------------------------
            let responseLoginSubmission = try await app.sendRequest(
                .POST,
                "/login",
                beforeRequest: ({ req async throws in
                    req.headers = ["Content-Type": "application/x-www-form-urlencoded"]
                    // fill the form
                    try req.content.encode(LoginForm(
                        username: "test_user",
                        password: "test_password",
                        location: locationString,
                        scope: scopeFormFiledValue.joined(separator: "+")
                    ))
                })
            )
            #expect(responseLoginSubmission.status == .seeOther)

            guard let cookie: HTTPCookies.Value = responseLoginSubmission.headers.setCookie?[Constants.COOKIE.NAME]
            else {
                Issue.record("No set cookie header")
                throw Abort(.badRequest)
            }

            let payload = try await SignerManager.shared.verify(cookie.string, as: Payload.self)

            #expect(payload.issuer == "http://127.0.0.1")
            #expect(payload.role == "test-user")

            // Verify SSO cookie contains both requested scope and provider scope
            #expect(payload.scope.contains("access"))
            #expect(payload.scope.contains("user:list"))

            // 3. Follow redirect to authorize endpoint
            // -----------------------------------
            guard let redirectLocation = responseLoginSubmission.headers["location"].first else {
                Issue.record("No redirect location")
                throw Abort(.badRequest)
            }

            let cleanedRedirectLocation = redirectLocation
                .replacingOccurrences(of: testServerAddress, with: "")
                .replacingOccurrences(of: "&amp;", with: "&")

            let responseAuthorizeRedirect = try await app.sendRequest(
                .GET,
                cleanedRedirectLocation,
                headers: [
                    "Cookie": cookie.serialize(name: Constants.COOKIE.NAME)
                ]
            )

            #expect(responseAuthorizeRedirect.status == .seeOther)

            // 4. Get the authorization code from the final redirect
            // -----------------------------------
            guard let finalRedirectLocation = responseAuthorizeRedirect.headers["location"].first else {
                Issue.record("No location header in authorize redirect")
                throw Abort(.badRequest)
            }

            let codeMatch = try finalRedirectLocation.groups(regex: "code=([a-zA-Z0-9]+)")
            #expect(codeMatch.count == 2, "Authorization code should be in redirect URL")
            let authorizationCode = codeMatch[1]

            // 5. Exchange authorization code for access token
            // -----------------------------------
            let tokenResponse = try await app.sendRequest(.POST, "/token", beforeRequest: {
                @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: authorizationCode).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })

            #expect(tokenResponse.status == .ok)

            let tokenResponseBody = try decoder.decode(TokenResponse.self, from: tokenResponse.body)
            #expect(tokenResponseBody.access_token.isEmpty == false)
            #expect(tokenResponseBody.refresh_token?.isEmpty == false)

            // 6. Verify TokenResponse has the correct scope string
            // -----------------------------------
            let expectedScopes = ["access", "user:list"].sorted()
            let actualScopes = (tokenResponseBody.scope ?? "").split(separator: " ").map { String($0) }.sorted()
            #expect(actualScopes == expectedScopes, "TokenResponse scope should match expected scopes")

            // 7. Decode JWT manually (without signature verification)
            // -----------------------------------
            let jwtParts = tokenResponseBody.access_token.split(separator: ".")
            #expect(jwtParts.count == 3, "JWT should have 3 parts")

            // Decode header
            let headerBase64 = String(jwtParts[0])
            let headerData = Data(base64Encoded: base64UrlToBase64(headerBase64))
            #expect(headerData != nil, "Should decode JWT header")

            var tokenKid: String?
            if let headerData = headerData {
                let header = try decoder.decode([String: String].self, from: headerData)
                #expect(header["alg"] == "RS256", "Token should use RS256 algorithm")
                #expect(header["typ"] == "JWT", "Token should have JWT type")
                #expect(header["kid"] != nil, "RS256 token should have kid (key ID)")
                tokenKid = header["kid"]
            }

            // Decode payload (note: NOT verifying signature here, as that's done in e2e tests)
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

                // Verify the access token payload contains the expected enriched scopes
                #expect(payload.scope.contains("access"), "Access token should contain 'access' scope")
                #expect(
                    payload.scope.contains("user:list"),
                    "Access token should contain 'user:list' from provider"
                )
                #expect(payload.tenant == "RS256 Scope Test Tenant", "Tenant should match")
                #expect(payload.sub == "test_user", "Subject should match")
            }

            // 8. Fetch JWKS and verify public key is available
            // -----------------------------------
            let jwksResponse = try await app.sendRequest(.GET, ".well-known/jwks.json")
            #expect(jwksResponse.status == .ok)

            let jwksBody = try decoder.decode(JWKSet.self, from: jwksResponse.body)
            #expect(jwksBody.keys.isEmpty == false, "JWKS should contain at least one key")

            // Find the key that matches the token's kid
            if let tokenKid = tokenKid {
                let matchingKey = jwksBody.keys.first { $0.kid == tokenKid }
                #expect(matchingKey != nil, "JWKS should contain the key with kid: \(tokenKid)")

                if let key = matchingKey {
                    #expect(key.kty == "RSA", "Key type should be RSA")
                    #expect(key.use == "sig", "Key use should be sig")
                    #expect(key.alg == "RS256", "Algorithm should be RS256")
                    #expect(key.n.isEmpty == false, "Modulus should not be empty")
                    #expect(key.e == "AQAB", "Exponent should be standard RSA exponent")
                }
            }

            // Note: Actual signature verification using the public key from JWKS
            // is tested in the e2e test suite (Tests/e2e/playwright/tests/OAuth/JwtValidation.spec.ts)
            // which uses the jsonwebtoken library to verify RS256 tokens using the public key.
            // This unit test verifies that:
            // 1. RS256 signing is configured correctly
            // 2. Scopes are properly merged (requested + provider)
            // 3. JWKS endpoint provides the public key in correct format
            // 4. Token's kid matches a key in JWKS
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
