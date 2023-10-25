import Foundation
import XCTVapor
@testable import Server

final class LoginControllerProfileTests: XCTestCase {
    var app: Application!

    override func setUp() {
        super.setUp()

        app = Application(.testing)
        try? configure(app)

        EntityStorage.shared.tenants.removeAll()
        EntityStorage.shared.clients.removeAll()

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
        let (inserted, _) = EntityStorage.shared.tenants.insert(tenant)
        XCTAssertTrue(inserted)

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

    func testLogin_CorrectProfile() async throws {
        let locationWithClient = "https://example.com/ok?client_id=".appending(
                EntityStorage.shared.clients.first?.config.ident.uuidString ?? ""
        )
        let response = try app.sendRequest(.POST, "login", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "sander@example.com", password: "secret", location: locationWithClient)
            )
        }))
        XCTAssertEqual(response.status, .seeOther)
        guard let cookie: String = response.headers["set-cookie"].first else {
            XCTFail("No Cookie set")
            return
        }

        let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
        XCTAssertEqual(contentGroups.count, 2)
        let token = contentGroups[1]

        let payload = try jwt_signer.verify(token, as: Payload.self)
        XCTAssertNotNil(payload.profile)
        guard let profile = payload.profile else {
            XCTFail("Can not get profile")
            return
        }

        guard let name = profile.object?["name"]?.string as? String else {
            XCTFail("Can not get name from profile")
            return
        }
        XCTAssertEqual(name, "Sander Foles")
    }

    func testLogin_JSProfile() async throws {
        let locationWithClient = "https://example.com/ok?client_id=".appending(
                EntityStorage.shared.clients.first?.config.ident.uuidString ?? ""
        )
        try app.test(.POST, "login", beforeRequest: ({ req in
            try req.content.encode(
                    LoginForm(username: "frodo@example.com", password: "secret", location: locationWithClient)
            )
        }), afterResponse: { res in
            XCTAssertEqual(res.status, .seeOther)
            guard let cookie: String = res.headers["set-cookie"].first else {
                XCTFail("No Cookie set")
                return
            }

            let contentGroups = try cookie.groups(regex: "uitsmijter-sso=([^;]+);")
            XCTAssertEqual(contentGroups.count, 2)
            let token = contentGroups[1]

            let payload = try jwt_signer.verify(token, as: Payload.self)
            XCTAssertNotNil(payload.profile)
            guard let profile = payload.profile else {
                XCTFail("Can not get profile")
                return
            }

            guard let name = profile.object?["name"]?.string as? String else {
                XCTFail("Can not get name from profile")
                return
            }
            XCTAssertEqual(name, "Frodo Baker")
        })
    }
}
