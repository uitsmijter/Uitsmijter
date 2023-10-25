import Foundation
import XCTVapor
@testable import Server

final class AuthControllerCodeClientWithSecretTest: XCTestCase {
    let testAppIdent = UUID()
    let testSecret = String.random(length: 12)
    var tenant: Tenant?
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClientWithSecret(uuid: testAppIdent, secret: testSecret)
        guard let tenant = EntityStorage.shared.clients.first(where: { $0.config.ident == testAppIdent })?.config.tenant
        else {
            XCTFail("Can not get tenant")
            return
        }
        self.tenant = tenant
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    // MARK: - Insecure

    func testCodeFlowEnsureClient() async throws {
        // get the tenant to save the id into the Payload
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&client_secret=\(testSecret)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .seeOther)
                }
        )
    }

    func testCodeFlowNoClientSecret() async throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    guard let tenant else {
                        throw TestError.fail(withError: "No tenant")
                    }
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .unauthorized)
                }
        )
    }

    func testCodeFlowWrongClientSecret() async throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&client_secret=_I_AM_NOT_SET"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    guard let tenant else {
                        throw TestError.fail(withError: "No tenant")
                    }
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .unauthorized)
                }
        )
    }

    // MARK: - Plain

    func testCodeFlowEnsureClientPlain() async throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&client_secret=\(testSecret)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge_method=plain"
                        + "&code_challenge=hello-world",
                beforeRequest: { req in
                    guard let tenant else {
                        throw TestError.fail(withError: "No tenant")
                    }
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .seeOther)
                }
        )
    }

    func testCodeFlowNoClientSecretPlain() async throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge_method=plain"
                        + "&code_challenge=hello-world",
                beforeRequest: { req in
                    guard let tenant else {
                        throw TestError.fail(withError: "No tenant")
                    }
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .unauthorized)
                }
        )
    }

    func testCodeFlowWrongClientSecretPlain() async throws {
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(testAppIdent.uuidString)"
                        + "&client_secret=_I_AM_NOT_SET"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123"
                        + "&code_challenge_method=plain"
                        + "&code_challenge=hello-world",
                beforeRequest: { req in
                    guard let tenant else {
                        throw TestError.fail(withError: "No tenant")
                    }
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.status, .unauthorized)
                }
        )
    }
}
