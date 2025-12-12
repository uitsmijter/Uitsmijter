import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("OAuth Controller Protocol Test")
@MainActor
struct OAuthControllerProtocolTest {
    class TestController: OAuthControllerProtocol {
    }

    struct InputScope: ScopesProtocol {
        var scope: String?
    }

    let testController = TestController()
    let client = UitsmijterClient(
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

    @Test("Allowed scopes explicit scope") func allowedScopesExplicitScope() {
        let inputScope: InputScope = InputScope(scope: "read")
        let allowedScopes = testController.allowedScopes(on: client, for: inputScope.scope?.components(separatedBy: .whitespacesAndNewlines) ?? [])
        #expect(allowedScopes.count == 1)
        #expect(allowedScopes.first == "read")
    }

    @Test("Allowed scopes with appends") func allowedScopesWithAppends() {
        let inputScope: InputScope = InputScope(scope: "admin_read")
        let allowedScopes = testController.allowedScopes(on: client, for: inputScope.scope?.components(separatedBy: .whitespacesAndNewlines) ?? [])
        #expect(allowedScopes.count == 1)
        #expect(allowedScopes.first == "admin_read")
    }

    @Test("Allowed scopes but not only base") func allowedScopesButNotOnlyBase() {
        let inputScope: InputScope = InputScope(scope: "admin_")
        let allowedScopes = testController.allowedScopes(on: client, for: inputScope.scope?.components(separatedBy: .whitespacesAndNewlines) ?? [])
        #expect(allowedScopes.isEmpty)
    }
}
