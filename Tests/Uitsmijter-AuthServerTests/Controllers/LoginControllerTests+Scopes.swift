@testable import Uitsmijter_AuthServer
import Testing
import VaporTesting

// Tests that the allowed scopes chain passes
@Suite("Login Controller Scopes Tests", .serialized)
struct LoginControllerScopesTests {

    @MainActor
    func setupEntities(app: Application) async throws {
        app.entityStorage.tenants.removeAll()
        app.entityStorage.clients.removeAll()

        var tenantConfig = TenantSpec(hosts: ["example.com", "example.org"])
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
                ident: UUID(),
                tenantname: tenant.name,
                redirect_urls: [
                    ".*\\.example\\.(org|com)",
                    "https://.*example\\.(org|com)/?.*",
                    "foo\\.example\\.com",
                    "wikipedia.org"
                ],
                scopes: ["read", "openid", "first:a", "test:*"],
                referrers: [
                    "example.com"
                ]
            )
        )
        app.entityStorage.clients = [client]
    }

    @Test("Post login form")
    func postLoginForm() async throws {
        try await withApp(configure: configure) { app in
            try await setupEntities(app: app)

            guard let firstClient = await app.entityStorage.clients.first else {
                Issue.record("There is no first client")
                return
            }
            let clientIdent = firstClient.config.ident
            try await app.testing().test(
                .POST,
                "login?client_id=\(clientIdent)", beforeRequest: { @Sendable req async throws in
                    try req.content.encode(
                        LoginForm(username: "ok@example.com", password: "secret", location: "https://example.com/ok")
                    )

                }, afterResponse: { @Sendable res async throws in
                    #expect(res.body.string.isEmpty)
                    #expect(res.status == .seeOther)
                    #expect(res.headers["location"].first == "https://example.com/ok")

                    guard let cookie: String = res.headers["set-cookie"].first else {
                        Issue.record("No Cookie set")
                        return
                    }

                    let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
                    #expect(contentGroups.count == 2)
                    let token = contentGroups[1]
                    #expect(token.count > 8)

                    let payload = try await SignerManager.shared.verify(token, as: Payload.self)
                    #expect(payload.subject == "ok_example.com")
                    dump(payload)

                    #expect(payload.role == "test-manager")
                })
        }
    }
}
