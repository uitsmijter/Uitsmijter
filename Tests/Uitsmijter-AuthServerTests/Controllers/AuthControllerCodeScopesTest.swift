import Foundation
import Testing
import VaporTesting
import CryptoSwift
@testable import Uitsmijter_AuthServer

///
///  ┌─────┐
///  │    client     │
///  └─────┘
///   openid
///   email
///   profile
///   user:delete
///         │
///         │
///         │    allowedRequestScopes:
///         │       openid
///         │       email
///         │       adress
///         │──────────────────────▶
///                                               openid
///                                               email
///                                                ┌────────┐
///                                                │   user provider    │
///                                                └────────┘
///                                               user:list
///                                               user:add
///                                               admin:all
///         ◀───────────────────────│
///         │
///         │   allowedProviderScopes:
///         │       user:*
///         │       can:*
///         │
///   openid
///   email
///   user:list
///   user:add
///

// Tests that the allowed scopes chain passes
@Suite("Auth Controller Code Scopes Test", .serialized)
struct AuthControllerCodeScopesTest {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    @MainActor
    func setupEntities(app: Application) async throws {
        app.entityStorage.tenants.removeAll()
        app.entityStorage.clients.removeAll()

        var tenantConfig = TenantSpec(hosts: ["127.0.0.1",
                                              "example.com",
                                              "localhost.localdomain",
                                              "localhost"])
        tenantConfig.providers.append(
            """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    scopes = [];
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.password);
                         this.isLoggedIn = true;
                         this.scopes = ["user:list", "user:add", "admin:all"]
                         commit({
                            subject: credentials.username.replace(/@/g, "_")
                         });
                    }

                    // Getter
                    get canLogin() {
                       return this.isLoggedIn;
                    }
                
                    get role(){
                        return "test-manager"
                    }
                
                    get scopes(){
                        return this.scopes
                    }

                    get userProfile() {
                       return {
                          name: "Sander Foles",
                          species: "Musician",
                          instruments: ["lead vocal", "guitar"]
                       };
                    }
                 }
                """
        )
        let tenant = Tenant(name: "Scope Test Tenant", config: tenantConfig)

        let (inserted, _) = app.entityStorage.tenants.insert(tenant)
        #expect(inserted)

        let client = Client(
            name: "First Client",
            config: ClientSpec(
                ident: testAppIdent,
                tenantname: tenant.name,
                redirect_urls: [
                    "http://localhost:?([0-9]+)?", "http://example.com"
                ],
                grant_types: ["password",
                              "authorization_code",
                              "refresh_token"],
                scopes: ["openid",
                         "email",
                         "adress"],
                allowedProviderScopes: [
                    "user:*",
                    "can:*"
                ],
                // "user:*" "can:*"
                referrers: [
                    ".*"
                ]
            )
        )
        app.entityStorage.clients = [client]
    }
    
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

    @Test("Valid users code flow PKCE S265 correct verifier")
    func testValidUsersCodeFlowPkceS265CorrectVerifier() async throws {
        try await withApp(configure: configure) { app in
            try await setupEntities(app: app)

            // 1. Request Code
            // -----------------------------------
            let state = String.random(length: 8)
            //let testServerAddress = "http://\(app.http.server.configuration.hostname):\(app.http.server.configuration.port)"
            let authorizeUrl = "/authorize"
                + "?response_type=code"
                + "&client_id=\(testAppIdent)"
                + "&redirect_uri=http://localhost:9090"
                + "&scope=openid+email+profile+user:delete"
                + "&state=\(state)"
            //let locationString = "\(testServerAddress)\(authorizeUrl.replacingOccurrences(of: "&", with: "&amp;"))"
            let responseAuthorize = try await app.sendRequest(
                .GET,
                authorizeUrl,
                headers: ["Content-Type": "application/json", "referer": "http://localhost:9090"]
            )

            #expect(responseAuthorize.status == .unauthorized)
            #expect(responseAuthorize.body.string.contains("<body"))
            #expect(responseAuthorize.body.string.contains("</html>"))
            #expect(responseAuthorize.body.string.contains("login"))

            // check scopes
            let scopeFormFiledValue: [String] = try {
                let value = try responseAuthorize.body.string.groups(
                    regex: "input\\s+type=\"hidden\"\\s+name=\"scope\"\\s+value=\"(.*)\""
                )
                if value.count != 2 {
                    return []
                }
                return value[1].split(separator: "+").map({String($0)}).sorted()
            }()

            #expect(scopeFormFiledValue.contains("email"))
            #expect(scopeFormFiledValue.contains("openid"))
            #expect(scopeFormFiledValue.contains("profile") == false)
            #expect(scopeFormFiledValue.contains("user:delte") == false)

            let testServerAddress = "http://\(app.http.server.configuration.hostname):\(app.http.server.configuration.port)"
            let locationString = "\(testServerAddress)\(authorizeUrl.replacingOccurrences(of: "&", with: "&amp;"))"

            // 2. Login
            // -----------------------------------
            let responseLoginSubmission = try await app.sendRequest(.POST, "/login", beforeRequest: ({ req async throws in
                req.headers = ["Content-Type": "application/x-www-form-urlencoded"]
                // fill the form
                try req.content.encode(LoginForm(
                    username: "valid_user",
                    password: "valid_password",
                    location: locationString,
                    scope: scopeFormFiledValue.joined(separator: "+")
                ))
            }))
            #expect(responseLoginSubmission.status == .seeOther)

            guard let cookie: HTTPCookies.Value = responseLoginSubmission.headers.setCookie?[Constants.COOKIE.NAME] else {
                Issue.record("No set cookie header")
                throw Abort(.badRequest)
            }

            dump(cookie)
            let payload = try await SignerManager.shared.verify(cookie.string, as: Payload.self)

            #expect(payload.issuer == "http://127.0.0.1")
            #expect(payload.role == "test-manager")

            #expect(payload.scope.contains("openid"))
            #expect(payload.scope.contains("email"))
            #expect(payload.scope.contains("user:list"))
            #expect(payload.scope.contains("user:add"))
            #expect(payload.scope.contains("user:delete") == false)
            #expect(payload.scope.contains("admin:all") == false)

            // Scopes are strings
            #expect(type(of: payload.scope) == String.self)

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
            let tokenResponse = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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

            // 6. Verify scopes in the final access token
            // -----------------------------------
            let accessTokenPayload = try await SignerManager.shared.verify(
                tokenResponseBody.access_token,
                as: Payload.self
            )

            // Verify the access token contains the expected enriched scopes
            #expect(accessTokenPayload.scope.contains("openid"), "Access token should contain 'openid' scope")
            #expect(accessTokenPayload.scope.contains("email"), "Access token should contain 'email' scope")
            #expect(accessTokenPayload.scope.contains("user:list"), "Access token should contain 'user:list' from provider")
            #expect(accessTokenPayload.scope.contains("user:add"), "Access token should contain 'user:add' from provider")
            #expect(accessTokenPayload.scope.contains("user:delete") == false, "Access token should NOT contain 'user:delete' (not in allowed scopes)")
            #expect(accessTokenPayload.scope.contains("admin:all") == false, "Access token should NOT contain 'admin:all' (not matching provider scope patterns)")

            // Verify TokenResponse also has the correct scope string
            let expectedScopes = ["email", "openid", "user:add", "user:list"].sorted()
            let actualScopes = (tokenResponseBody.scope ?? "").split(separator: " ").map { String($0) }.sorted()
            #expect(actualScopes == expectedScopes, "TokenResponse scope should match expected scopes")
        }
    }
}
