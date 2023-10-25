import Foundation

import XCTVapor
@testable import Server

final class InterceptorControllerNotConfiguredInClientTest: XCTestCase {
    let testAppIdent = UUID()
    let app = Application(.testing)
    var tenant: Tenant?

    override func setUp() {
        super.setUp()
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testInterceptorOnTenantWithoutInterceptorSettingsForwardToTarget() async throws {
        generateTestClient(uuid: testAppIdent)
        guard let tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )?.config.tenant
        else {
            return XCTFail("No tenant")
        }

        let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
            req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
            req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
            if let hostHeaderValue = tenant.config.hosts.first {
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: hostHeaderValue)
            }
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
        })

        XCTAssertEqual(response.status, .ok)
        XCTAssertNil(response.headers.setCookie)
    }

    func testInterceptorOnTenantWithInterceptorSettingsTrueForwardToTarget() async throws {
        generateTestClient(uuid: testAppIdent, includeGrantTypes: [.interceptor, .password])
        guard let tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )?.config.tenant
        else {
            return XCTFail("No tenant")
        }

        let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
            req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
            req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
            if let hostHeaderValue = tenant.config.interceptor?.domain {
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: hostHeaderValue)
            }
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
        })

        XCTAssertEqual(response.status, .ok)
        XCTAssertNil(response.headers.setCookie)
    }

    func testInterceptorOnTenantWithInterceptorSettingsFalseForwardToLogin() async throws {
        generateTestClient(uuid: testAppIdent, includeGrantTypes: [.password])
        guard let tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )?.config.tenant
        else {
            return XCTFail("No tenant")
        }

        let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
            req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
            req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
            if let hostHeaderValue = tenant.config.hosts.first {
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: hostHeaderValue)
            }
            req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
        })

        XCTAssertEqual(response.status, .forbidden)
    }
}
