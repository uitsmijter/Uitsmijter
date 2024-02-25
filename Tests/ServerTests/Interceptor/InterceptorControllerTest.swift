import Foundation

import XCTVapor
@testable import Server

final class InterceptorControllerTest: XCTestCase {
    let testAppIdent = UUID()
    let app = Application(.testing)
    var tenant: Tenant?

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent)
        guard let tenant = EntityStorage.shared.clients.first(where: { $0.config.ident == testAppIdent })?.config.tenant
        else {
            XCTFail("Can not get tenant.")
            return
        }
        self.tenant = tenant
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testInterceptorWithoutValidTokenShouldForwardToLogin() async throws {
        let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: "Unknown")
            req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
            req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: "127.0.0.1")
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
        })

        XCTAssertEqual(response.status, .temporaryRedirect)
        XCTAssertContains(
                response.headers.first(name: "location"),
                "http://localhost:8080/login?for=http://127.0.0.1/test"
        )
    }

    func testInterceptorWithoutValidHostForTenantShouldFail() throws {
        guard let tenant else {
            return XCTFail("No tenant")
        }
        let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
            req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
            req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
            req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: "10.0.0.1")
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
        })
        XCTAssertEqual(response.status, .badRequest)
    }

    func testInterceptorWithValidTokenShouldForwardToTarget() async throws {
        guard let tenant else {
            return XCTFail("No tenant")
        }
        let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
            req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
            req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
            req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: tenant.config.hosts.first ?? "_ERROR_")
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
        })

        XCTAssertEqual(response.status, .ok)
        XCTAssertNil(response.headers.setCookie)
    }

    func testInterceptorWithValidTokenShouldRenewToken() async throws {
        guard let tenant else {
            return XCTFail("No tenant")
        }
        let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
            let dateInFuture = Calendar.current.date(
                    byAdding: .hour,
                    value: -166,
                    to: Date()
            )

            XCTAssertGreaterThan(Date(), dateInFuture ?? Date())
            req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app, now: dateInFuture)
            req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
            req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: tenant.config.hosts.first ?? "_ERROR_")
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
        })

        XCTAssertEqual(response.status, .ok)
        XCTAssertNotNil(response.headers.setCookie)

        guard let cookie: HTTPCookies = response.headers.setCookie else {
            throw TestError.fail(withError: "No cookies in header")
        }
        XCTAssertEqual(cookie.all["uitsmijter-sso"]?.domain, "127.0.0.1")
        XCTAssertEqual(cookie.all["uitsmijter-sso"]?.path, "/")
        XCTAssertGreaterThan(cookie.all["uitsmijter-sso"]?.string.count ?? 0, 32)
    }
}
