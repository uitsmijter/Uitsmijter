@testable import Server
import XCTVapor

final class LoginControllerLoginTests: XCTestCase {
    var app: Application!

    override func setUp() {
        super.setUp()

        app = Application(.testing)
        try? configure(app)

        EntityStorage.shared.tenants.removeAll()
        EntityStorage.shared.clients.removeAll()

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

        let (inserted, _) = EntityStorage.shared.tenants.insert(tenant)
        XCTAssertTrue(inserted)

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
        EntityStorage.shared.clients = [client]
    }

    override func tearDown() {
        super.tearDown()
        app.shutdown()
    }

    func testPostLoginForm_WrongInterface() async throws {
        struct LoginFormFake: Content {
            let name: String
            let pass: String
            let page: String
        }

        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }

        try app.test(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(
                    LoginFormFake(name: "foo@example.com", pass: "secret", page: "https://something.com")
            )
        }), afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
            XCTAssertContains(res.body.string, LoginController.FrontendErrors.FORM_NOT_PARSEABLE.rawValue)
        })
    }

    func testPostLoginForm_UnparsableLocation() async throws {
        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }
        try app.test(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(LoginForm(username: "foo@example.com", password: "secret", location: "\nwhat\t."))
        }), afterResponse: { res in
            XCTAssertEqual(res.status, .preconditionFailed)
            XCTAssertContains(res.body.string, LoginController.FrontendErrors.MISSING_LOCATION.rawValue)
        })
    }

    func testPostLoginForm_UnknownUser() async throws {
        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }
        try app.test(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "foo@example.com", password: "secret", location: "https://example.com")
            )

        }), afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
            XCTAssertContains(res.body.string, "WRONG_CREDENTIALS")
        })
    }

    func testPostLoginForm_BadRedirect() async throws {
        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }
        try app.test(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: "https://zeit.de/ok")
            )

        }), afterResponse: { res in
            print(res.body.string)
            XCTAssertEqual(res.status, .forbidden)
        })
    }

    func testPostLoginForm_com_OK_Base() async throws {
        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }
        try app.test(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: "https://example.com/ok")
            )

        }), afterResponse: { res in
            print(res.body.string)
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers["location"].first, "https://example.com/ok")
        })
    }

    func testPostLoginForm_org_OK() async throws {
        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }
        try app.test(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: "https://example.org/ok")
            )

        }), afterResponse: { res in
            print(res.body.string)
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers["location"].first, "https://example.org/ok")
        })
    }

    func testPostLoginForm_com_OK_CheckToken() async throws {
        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }
        try app.test(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: "https://example.com/ok")
            )

        }), afterResponse: { res in
            print(res.headers)
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers["location"].first, "https://example.com/ok")
            XCTAssertTrue(res.headers.contains(name: .location))
            XCTAssertTrue(res.headers.contains(name: .contentLength))
            XCTAssertTrue(res.headers.contains(name: .setCookie))
            XCTAssertTrue(((res.headers["set-cookie"].first?.contains(Constants.COOKIE.NAME)) != nil))
            XCTAssertTrue(((res.headers["set-cookie"].first?.contains("Expires")) != nil))
            XCTAssertTrue(((res.headers["set-cookie"].first?.contains("Max-Age")) != nil))
            XCTAssertTrue(((res.headers["set-cookie"].first?.contains("Domain")) != nil))
            XCTAssertTrue(((res.headers["set-cookie"].first?.contains("Path")) != nil))
            XCTAssertTrue(((res.headers["set-cookie"].first?.contains("HttpOnly")) != nil))
            XCTAssertTrue(((res.headers["set-cookie"].first?.contains("SameSite")) != nil))
        })
    }

    func testPostLoginForm_com_OK_GetCookie() async throws {
        guard let firstClient = EntityStorage.shared.clients.first else {
            throw TestError.fail(withError: "There is no first client")
        }
        let response = try app.sendRequest(
                .POST,
                "login?client_id=\(firstClient.config.ident)", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: "https://example.com/ok")
            )
        }))

        XCTAssertEqual(response.status, .seeOther)
        XCTAssertEqual(response.headers["location"].first, "https://example.com/ok")

        guard let cookie: String = response.headers["set-cookie"].first else {
            XCTFail("No Cookie set")
            return
        }

        let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
        XCTAssertEqual(contentGroups.count, 2)
        let token = contentGroups[1]
        XCTAssertGreaterThan(token.count, 8)

        let payload = try jwt_signer.verify(token, as: Payload.self)
        XCTAssertEqual(payload.subject, "ok_example.com")
    }
}
