import Foundation
import XCTVapor
@testable import Server

class LoginControllerSilentDisallowTests: XCTestCase {
    var app: Application!
    let clientIdent = UUID()

    override func setUp() {
        super.setUp()

        app = Application(.testing)
        try? configure(app)

        EntityStorage.shared.tenants.removeAll()
        EntityStorage.shared.clients.removeAll()

        var tenantConfig = TenantSpec(
                hosts: ["localhost"],
                interceptor: nil,
                providers: [],
                silent_login: false
        )
        tenantConfig.providers.append(
                """
                 class UserLoginProvider {
                    isLoggedIn = false;
                    constructor(credentials) {
                         console.log("Credentials:", credentials.username, credentials.password);
                         this.isLoggedIn = true;
                         commit(
                            credentials.username === "ok@example.com",
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
        let (inserted, _) = EntityStorage.shared.tenants.insert(tenant)
        XCTAssertTrue(inserted)

        let client = Client(
                name: "First Client",
                config: ClientSpec(
                        ident: clientIdent,
                        tenantname: tenant.name,
                        redirect_urls: [
                            "localhost",
                            "foo.example.com"
                        ],
                        scopes: ["read"],
                        referrers: [
                        ]
                )
        )
        EntityStorage.shared.clients = [client]
    }

    override func tearDown() {
        super.tearDown()
        app.shutdown()
    }

    func testLoginWithValidAuthHeaderShouldFail() async throws {
        let locationWithClient = "https://localhost/?client_id=".appending(clientIdent.uuidString)
        let loginResponse = try app.sendRequest(
                .POST,
                "login",
                beforeRequest: ({ req in
                    try req.content.encode(
                            LoginForm(username: "ok@example.com", password: "secret", location: locationWithClient)
                    )
                })
        )

        XCTAssertNotNil(loginResponse.headers.setCookie)
        let cookie = loginResponse.headers["set-cookie"].first
        XCTAssertNotNil(cookie)

        let tok: String? = try cookie?.groups(regex: "uitsmijter-sso=([^;]+);")[1]
        try await app.test(.GET, "login?for=foo.example.com", beforeRequest: ({ req in
            _ = try await authorisationCodeGrantFlow(app: app, clientIdent: clientIdent)
            req.headers.bearerAuthorization = BearerAuthorization(
                    token: tok! // swiftlint:disable:this force_unwrapping
            )
        }), afterResponse: { res in
            XCTAssertTrue(res.body.string.contains("<title>Login</title>"))
            XCTAssertEqual(res.status, .ok)
        })
    }

    func testLoginWithValidCookieShouldFail() async throws {
        let locationWithClient = "https://localhost/&client_id=".appending(clientIdent.uuidString)
        let loginResponse = try app.sendRequest(.POST, "login", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "ok@example.com", password: "secret", location: locationWithClient)
            )
        }))
        XCTAssertNotNil(loginResponse.headers.setCookie)
        let cookie = loginResponse.headers["set-cookie"].first
        XCTAssertNotNil(cookie)

        try await app.test(.GET, "login?for=foo.example.com", beforeRequest: ({ req in
            _ = try await authorisationCodeGrantFlow(app: app, clientIdent: clientIdent)
            req.headers.add(name: "cookie", value: cookie!) // swiftlint:disable:this force_unwrapping

        }), afterResponse: { res in
            XCTAssertTrue(res.body.string.contains("<title>Login</title>"))
            XCTAssertEqual(res.status, .ok)
        })
    }
}
