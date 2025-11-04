import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Login Controller Silent Tests", .serialized)
// swiftlint:disable type_body_length
struct LoginControllerSilentTests {
    let clientIdent = UUID()

    @Test("Login with unknown token should fail")
    func loginWithUnknownTokenShouldFail() async throws {
        // swiftlint:disable:next closure_body_length
        try await withApp(configure: configure) { app in
            await MainActor.run {
                app.entityStorage.tenants.removeAll()
                app.entityStorage.clients.removeAll()
            }

            var tenantConfig = TenantSpec(
                hosts: ["localhost", "foo.example.com"],
                interceptor: nil,
                providers: [],
                silent_login: true
            )
            tenantConfig.providers.append(
                """
                     class UserLoginProvider {
                        isLoggedIn = false;
                        constructor(credentials) {
                             console.log("Credentials:", credentials.username, credentials.password);
                             this.isLoggedIn = true;
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
                        get role() {
                            return "front men"
                        }
                     }
                    """
            )
            let tenant = Tenant(
                name: "Test Tenant",
                config: tenantConfig
            )
            await MainActor.run {
                let (inserted, _) = app.entityStorage.tenants.insert(tenant)
                #expect(inserted)
            }

            let client = Client(
                name: "First Client",
                config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: [
                        "localhost",
                        "foo.example.com"
                    ],
                    scopes: ["read"] as [String],
                    referrers: nil
                )
            )
            await MainActor.run {
                app.entityStorage.clients = [client]
            }

            try await app.testing().test(
                .GET,
                "login?for=foo.example.com",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "not_valid")

                }, afterResponse: { @Sendable res async throws in
                #expect(res.body.string.contains("<title>Login</title>"))
                #expect(res.body.string.contains("foo.example.com"))
                #expect(res.status == .ok)
                })
        }
    }

    @Test("Login with unknown cookie should fail")
    func loginWithUnknownCookieShouldFail() async throws {
        // swiftlint:disable:next closure_body_length
        try await withApp(configure: configure) { app in
            await MainActor.run {
                app.entityStorage.tenants.removeAll()
                app.entityStorage.clients.removeAll()
            }

            var tenantConfig = TenantSpec(
                hosts: ["localhost", "foo.example.com"],
                interceptor: nil,
                providers: [],
                silent_login: true
            )
            tenantConfig.providers.append(
                """
                     class UserLoginProvider {
                        isLoggedIn = false;
                        constructor(credentials) {
                             console.log("Credentials:", credentials.username, credentials.password);
                             this.isLoggedIn = true;
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
                        get role() {
                            return "front men"
                        }
                     }
                    """
            )
            let tenant = Tenant(
                name: "Test Tenant",
                config: tenantConfig
            )
            await MainActor.run {
                let (inserted, _) = app.entityStorage.tenants.insert(tenant)
                #expect(inserted)
            }

            let client = Client(
                name: "First Client",
                config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: [
                        "localhost",
                        "foo.example.com"
                    ],
                    scopes: ["read"] as [String],
                    referrers: nil
                )
            )
            await MainActor.run {
                app.entityStorage.clients = [client]
            }

            try await app.testing().test(
                .GET,
                "login?for=foo.example.com",
                beforeRequest: { @Sendable req async throws in
                    req.headers.cookie = HTTPCookies(
                        dictionaryLiteral: (
                            Constants.COOKIE.NAME,
                            HTTPCookies.Value.defaultCookie(
                                expires: Date().advanced(by: -1),
                                withContent: "invalid"
                            )
                        )
                    )
                }, afterResponse: { @Sendable res async throws in
                #expect(res.body.string.contains("<title>Login</title>"))
                #expect(res.body.string.contains("foo.example.com"))
                #expect(res.status == .ok)
                })
        }
    }

    @Test("Login with valid auth header should pass")
    func loginWithValidAuthHeaderShouldPass() async throws {
        // swiftlint:disable:next closure_body_length
        try await withApp(configure: configure) { app in
            await MainActor.run {
                app.entityStorage.tenants.removeAll()
                app.entityStorage.clients.removeAll()
            }

            var tenantConfig = TenantSpec(
                hosts: ["localhost", "foo.example.com"],
                interceptor: nil,
                providers: [],
                silent_login: true
            )
            tenantConfig.providers.append(
                """
                     class UserLoginProvider {
                        isLoggedIn = false;
                        constructor(credentials) {
                             console.log("Credentials:", credentials.username, credentials.password);
                             this.isLoggedIn = true;
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
                        get role() {
                            return "front men"
                        }
                     }
                    """
            )
            let tenant = Tenant(
                name: "Test Tenant",
                config: tenantConfig
            )
            await MainActor.run {
                let (inserted, _) = app.entityStorage.tenants.insert(tenant)
                #expect(inserted)
            }

            let client = Client(
                name: "First Client",
                config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: [
                        "localhost",
                        "foo.example.com"
                    ],
                    scopes: ["read"] as [String],
                    referrers: nil
                )
            )
            await MainActor.run {
                app.entityStorage.clients = [client]
            }

            let locationWithClient = "https://localhost/&client_id=".appending(clientIdent.uuidString)
            let loginResponse = try await app.sendRequest(.POST, "login", beforeRequest: { @Sendable req async throws in
                try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: locationWithClient)
                )
            })
            #expect(loginResponse.headers.setCookie != nil)
            let cookie = loginResponse.headers["set-cookie"].first
            #expect(cookie != nil)
            let tok = try cookie?.groups(regex: "uitsmijter-sso=([^;]+);")[1]

            try await app.testing().test(
                .GET,
                "login?for=foo.example.com",
                beforeRequest: { @Sendable req async throws in
                    _ = try await authorisationCodeGrantFlow(app: app, clientIdent: clientIdent)
                    req.headers.bearerAuthorization = BearerAuthorization(
                        token: tok! // swiftlint:disable:this force_unwrapping
                    )
                }, afterResponse: { @Sendable res async throws in
                    #expect(res.status == .seeOther)
                    #expect(res.headers["location"].first == "foo.example.com")
                }
            )
        }
    }

    @Test("Login with valid cookie should pass")
    func loginWithValidCookieShouldPass() async throws {
        // swiftlint:disable:next closure_body_length
        try await withApp(configure: configure) { app in
            await MainActor.run {
                app.entityStorage.tenants.removeAll()
                app.entityStorage.clients.removeAll()
            }

            var tenantConfig = TenantSpec(
                hosts: ["localhost", "foo.example.com"],
                interceptor: nil,
                providers: [],
                silent_login: true
            )
            tenantConfig.providers.append(
                """
                     class UserLoginProvider {
                        isLoggedIn = false;
                        constructor(credentials) {
                             console.log("Credentials:", credentials.username, credentials.password);
                             this.isLoggedIn = true;
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
                        get role() {
                            return "front men"
                        }
                     }
                    """
            )
            let tenant = Tenant(
                name: "Test Tenant",
                config: tenantConfig
            )
            await MainActor.run {
                let (inserted, _) = app.entityStorage.tenants.insert(tenant)
                #expect(inserted)
            }

            let client = Client(
                name: "First Client",
                config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: [
                        "localhost",
                        "foo.example.com"
                    ],
                    scopes: ["read"] as [String],
                    referrers: nil
                )
            )
            await MainActor.run {
                app.entityStorage.clients = [client]
            }

            let locationWithClient = "https://localhost/&client_id=".appending(clientIdent.uuidString)
            let loginResponse = try await app.sendRequest(.POST, "login", beforeRequest: { @Sendable req async throws in
                try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: locationWithClient)
                )
            })
            #expect(loginResponse.headers.setCookie != nil)
            let cookie = loginResponse.headers["set-cookie"].first
            #expect(cookie != nil)

            try await app.testing().test(
                .GET,
                "login?for=foo.example.com",
                beforeRequest: { @Sendable req async throws in
                    _ = try await authorisationCodeGrantFlow(app: app, clientIdent: clientIdent)
                    req.headers.add(name: "cookie", value: cookie!) // swiftlint:disable:this force_unwrapping

                }, afterResponse: { @Sendable res async throws in
                #expect(res.status == .seeOther)
                #expect(res.headers["location"].first == "foo.example.com")
                })
        }
    }
}
// swiftlint:enable type_body_length
