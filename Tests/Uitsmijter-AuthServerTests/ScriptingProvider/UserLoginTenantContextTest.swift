import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("User Login Tenant Context Tests")
struct UserLoginTenantContextTest {

    /// Provider that echoes the tenant context it received back as the subject,
    /// so the test can assert the tenant name/namespace are passed into the JS context.
    let providerEchoTenant = """
                             class UserLoginProvider {
                                constructor(credentials) {
                                    const t = credentials.tenant;
                                    return commit({ subject: t.name + ":" + (t.namespace || "none") });
                                }
                                get canLogin() { return true; }
                                get userProfile() { return {}; }
                             }
                             """

    @Test("Provider receives tenant name and namespace")
    func providerReceivesTenantNameAndNamespace() async throws {
        let provider = JavaScriptProvider()
        try await provider.loadProvider(script: providerEchoTenant)

        let credentials = JSInputCredentials(
            username: "user@example.com",
            password: "secret",
            grantType: .authorization_code,
            tenant: JSInputTenant(name: "acme", namespace: "littleletter-uitsmijter")
        )
        let committed = try await provider.start(class: .userLogin, arguments: credentials)

        let subjects = Subject.decode(from: committed.compactMap({ $0 }))
        #expect(subjects.first?.subject == "acme:littleletter-uitsmijter")
    }

    @Test("Provider receives tenant name with nil namespace for file-based tenants")
    func providerReceivesTenantNameWithoutNamespace() async throws {
        let provider = JavaScriptProvider()
        try await provider.loadProvider(script: providerEchoTenant)

        let credentials = JSInputCredentials(
            username: "user@example.com",
            password: "secret",
            grantType: .authorization_code,
            tenant: JSInputTenant(name: "acme")
        )
        let committed = try await provider.start(class: .userLogin, arguments: credentials)

        let subjects = Subject.decode(from: committed.compactMap({ $0 }))
        #expect(subjects.first?.subject == "acme:none")
    }

    @Test("JSInputTenant splits namespace and name from a CRD tenant")
    func tenantContextFromKubernetesTenant() throws {
        // CRD tenants are stored internally as "<namespace>/<name>".
        let tenant = Tenant(
            ref: .kubernetes(UUID(), "rev-1"),
            name: "littleletter-uitsmijter/acme",
            config: TenantSpec(hosts: ["localhost"])
        )
        let context = JSInputTenant(from: tenant)
        #expect(context.name == "acme")
        #expect(context.namespace == "littleletter-uitsmijter")
    }

    @Test("JSInputTenant has no namespace for a file-based tenant")
    func tenantContextFromFileTenant() throws {
        let tenant = Tenant(
            ref: .file(URL(fileURLWithPath: "/tmp/tenant.yaml")),
            name: "file-tenant",
            config: TenantSpec(hosts: ["localhost"])
        )
        let context = JSInputTenant(from: tenant)
        #expect(context.name == "file-tenant")
        #expect(context.namespace == nil)
    }
}
