import Foundation
import Testing
import VaporTesting
import CryptoSwift
@testable import Uitsmijter_AuthServer


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
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.password);
                         if(credentials.username == "ok@example.com"){
                              this.isLoggedIn = true;
                         }
                         commit(
                            credentials.username == "ok@example.com",
                            {
                                subject: credentials.username.replace(/@/g, "_"),
                                scopes: "test:a test:b not:send first:a"
                            }
                         );
                    }

                    // Getter
                    get canLogin() {
                       return this.isLoggedIn;
                    }
                
                    get role(){
                        return "test-manager"
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
        let tenant = Tenant(name: "Test Tenant", config: tenantConfig)

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
                scopes: ["read", "openid", "first:a", "test:*"],
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
            // await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

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
