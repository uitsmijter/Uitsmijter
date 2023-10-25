import Foundation
import XCTVapor
@testable import Server

final class OAuthControllerProtocolTest: XCTestCase {
    class TestController: OAuthControllerProtocol {
    }

    struct InputScope: ScopesProtocol {
        var scope: String?
    }

    let testController = TestController()
    let client = Client(
            name: "test",
            config: ClientSpec(
                    ident: UUID(),
                    tenantname: "Test Tenant",
                    // tenant: Tenant(name: "Test Tenant", config: TenantSpec(hosts: ["example.com"])),
                    redirect_urls: ["http://localhost:9090"],
                    scopes: ["read", "admin_*", "*_list"],
                    referrers: ["http://localhost:8080/.*", ".*"]
            )
    )

    func testAllowedScopes_ExplicitScope() {
        let inputScope: InputScope = InputScope(scope: "read")
        let allowedScopes = testController.allowedScopes(on: client, for: inputScope)
        XCTAssertEqual(allowedScopes.count, 1)
        XCTAssertEqual(allowedScopes.first, "read")
    }

    func testAllowedScopes_WithAppends() {
        let inputScope: InputScope = InputScope(scope: "admin_read")
        let allowedScopes = testController.allowedScopes(on: client, for: inputScope)
        XCTAssertEqual(allowedScopes.count, 1)
        XCTAssertEqual(allowedScopes.first, "admin_read")
    }

    func testAllowedScopes_ButNotOnlyBase() {
        let inputScope: InputScope = InputScope(scope: "admin_")
        let allowedScopes = testController.allowedScopes(on: client, for: inputScope)
        XCTAssertEqual(allowedScopes.count, 0)
    }
}
