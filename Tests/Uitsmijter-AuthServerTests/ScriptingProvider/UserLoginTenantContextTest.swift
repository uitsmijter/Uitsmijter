import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("User Login Tenant Context Tests")
struct UserLoginTenantContextTest {

    /// Provider that echoes the tenant context it received back as the subject,
    /// so the test can assert the tenant name/id are passed into the JS context.
    let providerEchoTenant = """
                             class UserLoginProvider {
                                constructor(credentials) {
                                    const t = credentials.tenant;
                                    return commit({ subject: t.name + ":" + (t.id || "none") });
                                }
                                get canLogin() { return true; }
                                get userProfile() { return {}; }
                             }
                             """

    @Test("Provider receives tenant name and id")
    func providerReceivesTenantNameAndId() async throws {
        let provider = JavaScriptProvider()
        try await provider.loadProvider(script: providerEchoTenant)

        let credentials = JSInputCredentials(
            username: "user@example.com",
            password: "secret",
            grantType: .authorization_code,
            tenant: JSInputTenant(name: "acme", id: "abc-123")
        )
        let committed = try await provider.start(class: .userLogin, arguments: credentials)

        let subjects = Subject.decode(from: committed.compactMap({ $0 }))
        #expect(subjects.first?.subject == "acme:abc-123")
    }

    @Test("Provider receives tenant name with nil id for file-based tenants")
    func providerReceivesTenantNameWithoutId() async throws {
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

    @Test("JSInputTenant derives id from a Kubernetes tenant reference")
    func tenantContextFromKubernetesRef() throws {
        let uuid = UUID()
        let tenant = Tenant(
            ref: .kubernetes(uuid, "rev-1"),
            name: "k8s-tenant",
            config: TenantSpec(hosts: ["localhost"])
        )
        let context = JSInputTenant(from: tenant)
        #expect(context.name == "k8s-tenant")
        #expect(context.id == uuid.uuidString)
    }

    @Test("JSInputTenant has no id for a file-based tenant reference")
    func tenantContextFromFileRef() throws {
        let tenant = Tenant(
            ref: .file(URL(fileURLWithPath: "/tmp/tenant.yaml")),
            name: "file-tenant",
            config: TenantSpec(hosts: ["localhost"])
        )
        let context = JSInputTenant(from: tenant)
        #expect(context.name == "file-tenant")
        #expect(context.id == nil)
    }
}
