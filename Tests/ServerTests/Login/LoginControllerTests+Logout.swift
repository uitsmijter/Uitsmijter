@testable import Server
import XCTVapor

final class LoginControllerLogoutTests: XCTestCase {
    var app: Application!

    private var token: String?

    override func setUp() async throws {
        try await super.setUp()

        app = Application(.testing)
        try? configure(app)

        // login
        setupTenant()
        try? await loginUser()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        app.shutdown()
    }

    private func loginUser() async throws {
        let response = try app.sendRequest(.POST, "login", beforeRequest: ({ req in
            req.headers.add(name: "client_id", value: EntityStorage.shared.clients.first?.config.ident.uuidString ?? "")
            try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: "https://example.com/ok")
            )
        }))

        XCTAssertEqual(response.status, .seeOther)
        XCTAssertTrue(response.headers["location"].first?.starts(with: "https://example.com/ok") ?? false)

        guard let cookie: String = response.headers["set-cookie"].first else {
            XCTFail("No Cookie set")
            return
        }

        do {
            let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
            XCTAssertEqual(contentGroups.count, 2)
            token = contentGroups[1]
        } catch {
            XCTFail("error: \(error)")
        }
    }

    func testLogout_NotLoggedIn() async throws {
        let response = try await app.sendRequest(
                .GET,
                "logout?location=http://example.com/",
                headers: ["X-Forwarded-Host": "example.com"]
        )
        XCTAssertEqual(response.status, .ok)
        XCTAssertContains(response.body.string, "logout/finalize")
    }

    func testLogout_LoggedIn() async throws {
        let response = try app.sendRequest(
                .GET,
                "logout/finalize",
                beforeRequest: ({ req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: self.token ?? "_ERROR_")
                })
        )

        XCTAssertEqual(response.headers["location"].first, "/")
        XCTAssertContains(response.headers["set-cookie"]
                .filter({ $0.contains(Constants.COOKIE.NAME) })
                .first, "\(Constants.COOKIE.NAME)=invalid")
        XCTAssertEqual(response.status, .seeOther)
    }

    func testLogout_Uri() async throws {
        let response = try app.sendRequest(.GET, "logout/finalize?location=/out", beforeRequest: ({ req in
            req.headers.bearerAuthorization = BearerAuthorization(token: self.token ?? "_ERROR_")
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/out")
        }))
        XCTAssertEqual(response.headers["location"].first, "/out")
        XCTAssertContains(response.headers["set-cookie"]
                .filter({ $0.contains(Constants.COOKIE.NAME) })
                .first,
                "\(Constants.COOKIE.NAME)=invalid"
        )
        XCTAssertEqual(response.status, .seeOther)

    }
}
