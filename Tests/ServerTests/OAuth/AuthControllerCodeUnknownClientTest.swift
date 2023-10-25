import Foundation
import XCTVapor
@testable import Server

final class AuthControllerCodeUnknownClientTest: XCTestCase {
    let testAppIdent = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()
        generateTestClient(uuid: testAppIdent)

        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

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

    func testCodeFlowUnknownClientJSON() async throws {
        // get the tenant to save the id into the Payload
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        let newClientIdent = UUID()
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(newClientIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.headers.contentType, HTTPMediaType.json)
                    XCTAssertEqual(res.status, .badRequest)
                    XCTAssertContains(res.body.string, "\"error\":true")
                    XCTAssertContains(res.body.string, "LOGIN.ERRORS.NO_CLIENT")
                    XCTAssertTrue(res.body.string.starts(with: "{")) // is a json object
                }
        )
    }

    func testCodeFlowUnknownClientHTML() async throws {
        // get the tenant to save the id into the Payload
        guard let tenant: Tenant = EntityStorage.shared.clients.first(
                where: { $0.config.ident == testAppIdent }
        )!.config.tenant // swiftlint:disable:this force_unwrapping
        else {
            XCTFail("No tenant in client")
            throw TestError.abort
        }

        let newClientIdent = UUID()
        try app.test(
                .GET,
                "authorize"
                        + "?response_type=code"
                        + "&client_id=\(newClientIdent.uuidString)"
                        + "&redirect_uri=http://localhost/"
                        + "&scope=test"
                        + "&state=123",
                beforeRequest: { req in
                    req.headers.add(name: "Accept", value: "text/html")
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { res in
                    XCTAssertEqual(res.headers.contentType, HTTPMediaType.html)
                    XCTAssertEqual(res.status, .badRequest)
                    XCTAssertContains(res.body.string, "<html")
                    XCTAssertContains(res.body.string, "<title>Error | 400</title>")
                    XCTAssertContains(res.body.string, "class=\"error-headline\"")
                    XCTAssertContains(res.body.string, "LOGIN.ERRORS.NO_CLIENT")
                }
        )
    }
}
