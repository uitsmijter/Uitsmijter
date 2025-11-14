import Foundation
@testable import Uitsmijter_AuthServer
import Testing

/// Tests for ClientSpec tenant extension
@Suite("Client+Tenant Tests")
@MainActor
struct ClientTenantTest {

    @Test("ClientSpec tenant property returns nil when tenant not found")
    func tenantPropertyReturnsNilWhenNotFound() async {
        let storage = EntityStorage()
        // Clear any existing tenants
        storage.tenants.removeAll()

        let clientSpec = ClientSpec(
            ident: UUID(),
            tenantname: "NonExistentTenant",
            redirect_urls: []
        )

        #expect(clientSpec.tenant(in: storage) == nil)
    }

    @Test("ClientSpec tenant property returns tenant when found")
    func tenantPropertyReturnsTenantWhenFound() async {
        let storage = EntityStorage()
        // Clear and setup
        storage.tenants.removeAll()

        // Create a tenant
        let tenantConfig = TenantSpec(
            hosts: ["example.com"]
        )
        let tenant = Tenant(
            ref: .file(URL(fileURLWithPath: "/tmp/test.yaml")),
            name: "ExistingTenant",
            config: tenantConfig
        )
        storage.tenants.insert(tenant)

        // Create client spec referencing this tenant
        let clientSpec = ClientSpec(
            ident: UUID(),
            tenantname: "ExistingTenant",
            redirect_urls: []
        )

        let foundTenant = clientSpec.tenant(in: storage)
        #expect(foundTenant != nil)
        #expect(foundTenant?.name == "ExistingTenant")

        // Cleanup
        storage.tenants.removeAll()
    }

    @Test("ClientSpec tenant property is case-sensitive")
    func tenantPropertyIsCaseSensitive() async {
        let storage = EntityStorage()
        // Clear and setup
        storage.tenants.removeAll()

        // Create a tenant with specific casing
        let tenantConfig = TenantSpec(
            hosts: ["example.com"]
        )
        let tenant = Tenant(
            ref: .file(URL(fileURLWithPath: "/tmp/test.yaml")),
            name: "MyTenant",
            config: tenantConfig
        )
        storage.tenants.insert(tenant)

        // Try to find with different casing
        let clientSpec = ClientSpec(
            ident: UUID(),
            tenantname: "mytenant",  // lowercase
            redirect_urls: []
        )

        // Should not find (case mismatch)
        #expect(clientSpec.tenant(in: storage) == nil)

        // Cleanup
        storage.tenants.removeAll()
    }

    @Test("ClientSpec tenant property returns correct tenant from multiple")
    func tenantPropertyReturnsCorrectTenantFromMultiple() async {
        let storage = EntityStorage()
        // Clear and setup
        storage.tenants.removeAll()

        // Create multiple tenants
        let tenant1 = Tenant(
            ref: .file(URL(fileURLWithPath: "/tmp/tenant1.yaml")),
            name: "Tenant1",
            config: TenantSpec(hosts: ["tenant1.com"])
        )
        let tenant2 = Tenant(
            ref: .file(URL(fileURLWithPath: "/tmp/tenant2.yaml")),
            name: "Tenant2",
            config: TenantSpec(hosts: ["tenant2.com"])
        )
        let tenant3 = Tenant(
            ref: .file(URL(fileURLWithPath: "/tmp/tenant3.yaml")),
            name: "Tenant3",
            config: TenantSpec(hosts: ["tenant3.com"])
        )

        storage.tenants.insert(tenant1)
        storage.tenants.insert(tenant2)
        storage.tenants.insert(tenant3)

        // Client referencing Tenant2
        let clientSpec = ClientSpec(
            ident: UUID(),
            tenantname: "Tenant2",
            redirect_urls: []
        )

        let foundTenant = clientSpec.tenant(in: storage)
        #expect(foundTenant != nil)
        #expect(foundTenant?.name == "Tenant2")
        #expect(foundTenant?.config.hosts.contains("tenant2.com") == true)

        // Cleanup
        storage.tenants.removeAll()
    }
}
