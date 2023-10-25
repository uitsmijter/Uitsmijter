import Foundation
import XCTVapor
@testable import Server

final class AuthControllerDifferentTenantsTest: XCTestCase {
    let testAppIdent1 = UUID()
    let testAppIdent2 = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()

        generateTestClientsWithMultipleTenants(uuids: [testAppIdent1, testAppIdent2], script: .johnDoe)
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCreatedExpectedSet() {
        XCTAssertGreaterThanOrEqual(EntityStorage.shared.tenants.count, 2)
        XCTAssertGreaterThanOrEqual(EntityStorage.shared.clients.count, 2)
    }

    func testCanLoginInsecureWithCorrectClient() async throws {
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent1 }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }
        let response = try app.sendRequest(
                .GET,
                "authorize?"
                        + "response_type=code"
                        + "&client_id=\(testAppIdent1.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                }
        )
        XCTAssertEqual(response.status, .seeOther)
    }

    func testCanLoginPKCEWithCorrectClient() async throws {
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent1 }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        let response = try app.sendRequest(
                .GET,
                "authorize?"
                        + "response_type=code"
                        + "&client_id=\(testAppIdent1.uuidString)"
                        + "&redirect_uri=http://localhost/&scope=test"
                        + "&state=123"
                        + "&code_challenge=aem5AeKo"
                        + "&code_challenge_method=plain",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                })
        XCTAssertEqual(response.status, .seeOther)
    }

    func testCanNotLoginInsecureWithWithAuthenticationFromOtherTenant() async throws {
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent1 }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        let response = try app.sendRequest(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent2.uuidString)"
                        + "&redirect_uri=http://localhost/&scope=test&state=123",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                }
        )
        XCTAssertEqual(response.status, .forbidden)
    }

    func testCanNotLoginPKCEWithWithAuthenticationFromOtherTenant() async throws {
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent1 }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        let response = try app.sendRequest(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent2.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge=aem5AeKo"
                        + "&code_challenge_method=plain",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                })
        XCTAssertEqual(response.status, .forbidden)
    }

}
