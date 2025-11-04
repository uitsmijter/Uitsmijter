@testable import Uitsmijter_AuthServer
import Testing
import VaporTesting

@Suite("Login Controller Logout Tests", .serialized)
struct LoginControllerLogoutTests {

    func performLoginAndGetToken(app: Application) async throws -> String? {
        // login
        await setupTenant(app: app)

        let response = try await app.sendRequest(.POST, "login", beforeRequest: { @Sendable req async throws in
            req.headers.add(
                name: "client_id",
                value: await app.entityStorage.clients.first?.config.ident.uuidString ?? ""
            )
            try req.content.encode(
                LoginForm(username: "ok@example.com", password: "secret", location: "https://example.com/ok")
            )
        })
        #expect(response.status == .seeOther)
        #expect(response.headers["location"].first?.starts(with: "https://example.com/ok") ?? false)

        guard let cookie: String = response.headers["set-cookie"].first else {
            Issue.record("No Cookie set")
            return nil
        }

        let token: String?
        do {
            let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
            #expect(contentGroups.count == 2)
            token = contentGroups[1]
        } catch {
            Issue.record("error: \(error)")
            token = nil
        }

        return token
    }

    @Test("Logout not logged in")
    func logoutNotLoggedIn() async throws {
        try await withApp(configure: configure) { app in
            await setupTenant(app: app)

            let response = try await app.sendRequest(
                .GET,
                "logout?location=http://example.com/",
                headers: ["X-Forwarded-Host": "example.com"]
            )
            #expect(response.status == .ok)
            #expect(response.body.string.contains("logout/finalize"))
        }
    }

    @Test("Logout logged in")
    func logoutLoggedIn() async throws {
        try await withApp(configure: configure) { app in
            let token = try await performLoginAndGetToken(app: app)

            try await app.testing().test(.GET, "logout/finalize", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: token ?? "_ERROR_")
            }, afterResponse: { @Sendable response async throws in
                #expect(response.headers["location"].first == "/")
                #expect(response.headers["set-cookie"]
                            .filter({ $0.contains(Constants.COOKIE.NAME) })
                            .first?.contains("\(Constants.COOKIE.NAME)=invalid") ?? false)
                #expect(response.status == .seeOther)
            })
        }
    }

    @Test("Logout URI")
    func logoutUri() async throws {
        try await withApp(configure: configure) { app in
            let token = try await performLoginAndGetToken(app: app)

            try await app.testing().test(
                .GET,
                "logout/finalize?location=/out",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = BearerAuthorization(token: token ?? "_ERROR_")
                    req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/out")
                }, afterResponse: { @Sendable response async throws in
                #expect(response.headers["location"].first == "/out")
                #expect(response.headers["set-cookie"]
                            .filter({ $0.contains(Constants.COOKIE.NAME) })
                            .first?.contains("\(Constants.COOKIE.NAME)=invalid") ?? false)
                #expect(response.status == .seeOther)
                })
        }
    }
}
