@testable import Uitsmijter_AuthServer
import Testing
import VaporTesting

@Suite("Login Controller Login Tests", .serialized)
// swiftlint:disable:next type_body_length
struct LoginControllerLoginTests {

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
                            {subject: credentials.username.replace(/@/g, "_")}
                         );
                    }

                    // Getter
                    get canLogin() {
                       return this.isLoggedIn;
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

        let (inserted, _) = await app.entityStorage.tenants.insert(tenant)
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
                scopes: ["read"],
                referrers: [
                    "example.com"
                ]
            )
        )
        app.entityStorage.clients = [client]
    }

    @Test("Post login form wrong interface")
    func postLoginFormWrongInterface() async throws {
        struct LoginFormFake: Content {
            let name: String
            let pass: String
            let page: String
        }

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
                        LoginFormFake(name: "foo@example.com", pass: "secret", page: "https://something.com")
                    )
                }, afterResponse: { @Sendable res async throws in
                    #expect(res.status == .badRequest)
                    #expect(res.body.string.contains(LoginController.FrontendErrors.FORM_NOT_PARSEABLE.rawValue))
                })
        }
    }

    @Test("Post login form unparsable location")
    func postLoginFormUnparsableLocation() async throws {
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
                        LoginForm(username: "foo@example.com", password: "secret", location: "\nwhat\t.")
                    )
                }, afterResponse: { @Sendable res async throws in
                    #expect(res.status == .preconditionFailed)
                    #expect(res.body.string.contains(LoginController.FrontendErrors.MISSING_LOCATION.rawValue))
                })
        }
    }

    @Test("Post login form unknown user")
    func postLoginFormUnknownUser() async throws {
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
                        LoginForm(username: "foo@example.com", password: "secret", location: "https://example.com")
                    )

                }, afterResponse: { @Sendable res async throws in
                    #expect(res.status == .forbidden)
                    #expect(res.body.string.contains("WRONG_CREDENTIALS"))
                })
        }
    }

    @Test("Post login form bad redirect")
    func postLoginFormBadRedirect() async throws {
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
                        LoginForm(username: "ok@example.com", password: "secret", location: "https://zeit.de/ok")
                    )

                }, afterResponse: { @Sendable res async throws in
                    print(res.body.string)
                    #expect(res.status == .forbidden)
                })
        }
    }

    @Test("Post login form com OK base")
    func postLoginFormComOKBase() async throws {
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
                    print(res.body.string)
                    #expect(res.status == .seeOther)
                    #expect(res.headers["location"].first == "https://example.com/ok")
                })
        }
    }

    @Test("Post login form org OK")
    func postLoginFormOrgOK() async throws {
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
                        LoginForm(username: "ok@example.com", password: "secret", location: "https://example.org/ok")
                    )

                }, afterResponse: { @Sendable res async throws in
                    print(res.body.string)
                    #expect(res.status == .seeOther)
                    #expect(res.headers["location"].first == "https://example.org/ok")
                })
        }
    }

    @Test("Post login form com OK check token")
    func postLoginFormComOKCheckToken() async throws {
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
                    print(res.headers)
                    #expect(res.status == .seeOther)
                    #expect(res.headers["location"].first == "https://example.com/ok")
                    #expect(res.headers.contains(name: .location))
                    #expect(res.headers.contains(name: .contentLength))
                    #expect(res.headers.contains(name: .setCookie))
                    #expect(((res.headers["set-cookie"].first?.contains(Constants.COOKIE.NAME)) != nil))
                    #expect(((res.headers["set-cookie"].first?.contains("Expires")) != nil))
                    #expect(((res.headers["set-cookie"].first?.contains("Max-Age")) != nil))
                    #expect(((res.headers["set-cookie"].first?.contains("Domain")) != nil))
                    #expect(((res.headers["set-cookie"].first?.contains("Path")) != nil))
                    #expect(((res.headers["set-cookie"].first?.contains("HttpOnly")) != nil))
                    #expect(((res.headers["set-cookie"].first?.contains("SameSite")) != nil))
                })
        }
    }

    @Test("Post login form com OK get cookie")
    func postLoginFormComOKGetCookie() async throws {
        try await withApp(configure: configure) { app in
            try await setupEntities(app: app)

            guard let firstClient = await app.entityStorage.clients.first else {
                Issue.record("There is no first client")
                return
            }
            let clientIdent = firstClient.config.ident
            try await app.testing().test(
                .POST,
                "login?client_id=\(clientIdent)",
                beforeRequest: { @Sendable req async throws in
                    try req.content.encode(
                        LoginForm(username: "ok@example.com", password: "secret", location: "https://example.com/ok")
                    )
                }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .seeOther)
                #expect(response.headers["location"].first == "https://example.com/ok")

                guard let cookie: String = response.headers["set-cookie"].first else {
                    Issue.record("No Cookie set")
                    return
                }

                let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
                #expect(contentGroups.count == 2)
                let token = contentGroups[1]
                #expect(token.count > 8)

                let payload = try await SignerManager.shared.verify(token, as: Payload.self)
                #expect(payload.subject == "ok_example.com")
                })
        }
    }
}
