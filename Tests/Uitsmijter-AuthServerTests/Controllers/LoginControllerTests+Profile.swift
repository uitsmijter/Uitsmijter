import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

// Tests use unique kid values so they don't interfere with each other
@Suite("Login Controller Profile Tests", .serialized)
// swiftlint:disable type_body_length
struct LoginControllerProfileTests {

    @MainActor
    func setupApp() async throws -> Application {
        let app = try await Application.make(.testing)
        try? await configure(app)

        app.entityStorage.tenants.removeAll()
        app.entityStorage.clients.removeAll()

        var tenantConfig = TenantSpec(hosts: [
            "example.com",
            "example.org"
        ])
        tenantConfig.providers.append(
            """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    profile = null;
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.password);
                         if(credentials.username == "sander@example.com"){
                              this.isLoggedIn = true;
                              this.profile = {
                                  "name": "Sander Foles",
                                  "species": "Musician",
                                  "instruments": ["lead vocal", "guitar"]
                               };
                         }
                         if(credentials.username == "frodo@example.com"){
                              this.isLoggedIn = true;
                              this.profile = {
                                  name: "Frodo Baker",
                                  species: "Musician",
                                  instruments: ["trumpet"]
                               };
                         }
                         commit(true, {subject: credentials.username.replace(/@/g, "_")});
                    }

                    // Getter
                    get canLogin() {
                       return this.isLoggedIn;
                    }

                    get userProfile() {
                       return this.profile;
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
                    ".*\\.?example\\.(org|com)",
                    "foo\\.example\\.com",
                    "wikipedia.org"
                ],
                scopes: ["read"] as [String]?,
                referrers: [
                    "example.com"
                ] as [String]?
            )
        )
        app.entityStorage.clients = [client]

        return app
    }

    @Test("Login correct profile")
    // swiftlint:disable:next function_body_length
    func loginCorrectProfile() async throws {
        // swiftlint:disable:next closure_body_length
        try await withApp(configure: configure) { app in
            // Setup from setupApp() - inline here instead
            await MainActor.run {
                app.entityStorage.tenants.removeAll()
                app.entityStorage.clients.removeAll()
            }

            var tenantConfig = TenantSpec(hosts: [
                "example.com",
                "example.org"
            ])
            tenantConfig.providers.append(
                """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    profile = null;
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.password);
                         if(credentials.username == "sander@example.com"){
                              this.isLoggedIn = true;
                              this.profile = {
                                  "name": "Sander Foles",
                                  "species": "Musician",
                                  "instruments": ["lead vocal", "guitar"]
                               };
                         }
                         if(credentials.username == "frodo@example.com"){
                              this.isLoggedIn = true;
                              this.profile = {
                                  name: "Frodo Baker",
                                  species: "Musician",
                                  instruments: ["lead vocal", "guitar"]
                               };
                         }
                         commit(this.isLoggedIn, {subject: credentials.username});
                    }
                    get canLogin() { return this.isLoggedIn; }
                    get userProfile() { return this.profile; }
                 }
                """
            )
            let tenant = Tenant(name: "Test Tenant", config: tenantConfig)
            await MainActor.run {
                let (inserted, _) = app.entityStorage.tenants.insert(tenant)
                #expect(inserted)
            }

            let client = Client(
                name: "First Client",
                config: ClientSpec(
                    ident: UUID(),
                    tenantname: tenant.name,
                    redirect_urls: [
                        ".*\\.?example\\.(org|com)",
                        "foo\\.example\\.com",
                        "wikipedia.org"
                    ],
                    scopes: ["read"] as [String],
                    referrers: [
                        "example.com"
                    ] as [String]
                )
            )
            await MainActor.run {
                app.entityStorage.clients = [client]
            }

            let locationWithClient = "https://example.com/ok?client_id=".appending(
                await app.entityStorage.clients.first?.config.ident.uuidString ?? ""
            )
            try await app.testing().test(.POST, "login", beforeRequest: { @Sendable req async throws in
                try req.content.encode(
                    LoginForm(username: "sander@example.com", password: "secret", location: locationWithClient)
                )
            }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .seeOther)
                guard let cookie: String = response.headers["set-cookie"].first else {
                    Issue.record("No Cookie set")
                    return
                }

                let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
                #expect(contentGroups.count == 2)
                let token = contentGroups[1]

                let payload = try await SignerManager.shared.verify(token, as: Payload.self)
                #expect(payload.profile != nil)
                guard let profile = payload.profile else {
                    Issue.record("Can not get profile")
                    return
                }

                guard let name = profile.object?["name"]?.string else {
                    Issue.record("Can not get name from profile")
                    return
                }
                #expect(name == "Sander Foles")
            })
        }
    }

    @Test("Login JS profile")
    // swiftlint:disable:next function_body_length
    func loginJSProfile() async throws {
        // swiftlint:disable:next closure_body_length
        try await withApp(configure: configure) { app in
            // Setup from setupApp() - inline here instead
            await MainActor.run {
                app.entityStorage.tenants.removeAll()
                app.entityStorage.clients.removeAll()
            }

            var tenantConfig = TenantSpec(hosts: [
                "example.com",
                "example.org"
            ])
            tenantConfig.providers.append(
                """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    profile = null;
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.username, credentials.password);
                         if(credentials.username == "sander@example.com"){
                              this.isLoggedIn = true;
                              this.profile = {
                                  "name": "Sander Foles",
                                  "species": "Musician",
                                  "instruments": ["lead vocal", "guitar"]
                               };
                         }
                         if(credentials.username == "frodo@example.com"){
                              this.isLoggedIn = true;
                              this.profile = {
                                  name: "Frodo Baker",
                                  species: "Musician",
                                  instruments: ["lead vocal", "guitar"]
                               };
                         }
                         commit(this.isLoggedIn, {subject: credentials.username});
                    }
                    get canLogin() { return this.isLoggedIn; }
                    get userProfile() { return this.profile; }
                 }
                """
            )
            let tenant = Tenant(name: "Test Tenant", config: tenantConfig)
            await MainActor.run {
                let (inserted, _) = app.entityStorage.tenants.insert(tenant)
                #expect(inserted)
            }

            let client = Client(
                name: "First Client",
                config: ClientSpec(
                    ident: UUID(),
                    tenantname: tenant.name,
                    redirect_urls: [
                        ".*\\.?example\\.(org|com)",
                        "foo\\.example\\.com",
                        "wikipedia.org"
                    ],
                    scopes: ["read"] as [String],
                    referrers: [
                        "example.com"
                    ] as [String]
                )
            )
            await MainActor.run {
                app.entityStorage.clients = [client]
            }

            let locationWithClient = "https://example.com/ok?client_id=".appending(
                await app.entityStorage.clients.first?.config.ident.uuidString ?? ""
            )
            try await app.testing().test(.POST, "login", beforeRequest: { @Sendable req async throws in
                try req.content.encode(
                    LoginForm(username: "frodo@example.com", password: "secret", location: locationWithClient)
                )
            }, afterResponse: { @Sendable res async throws in
                #expect(res.status == .seeOther)
                guard let cookie: String = res.headers["set-cookie"].first else {
                    Issue.record("No Cookie set")
                    return
                }

                let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
                #expect(contentGroups.count == 2)
                let token = contentGroups[1]

                let payload = try await SignerManager.shared.verify(token, as: Payload.self)
                #expect(payload.profile != nil)
                guard let profile = payload.profile else {
                    Issue.record("Can not get profile")
                    return
                }

                guard let name = profile.object?["name"]?.string else {
                    Issue.record("Can not get name from profile")
                    return
                }
                #expect(name == "Frodo Baker")
            })
        }
    }
}
// swiftlint:enable type_body_length
