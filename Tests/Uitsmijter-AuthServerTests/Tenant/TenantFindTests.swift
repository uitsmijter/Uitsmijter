import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@MainActor
@Suite(.serialized) struct TenantFindTests {

    // MARK: - find by Host

    @Test func findTenantByHost() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        storage.tenants.removeAll()
        let tenant = Tenant(ref: .file(temporaryFile), name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let foundTenant = Tenant.find(in: storage, forHost: "example.com")
        #expect(foundTenant != nil)
        #expect(foundTenant?.name == "Test Tenant")
    }

    @Test func findWithMoreHostsTenant() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        storage.tenants.removeAll()
        let tenant = Tenant(ref: .file(temporaryFile), name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let tenant2 = Tenant(
            name: "Second Test Tenant",
            config: TenantSpec(hosts: ["example_A.com", "example_B.com", "example_C.com"])
        )
        let (inserted2, _) = storage.tenants.insert(tenant2)
        #expect(inserted2)

        let foundTenant_1 = Tenant.find(in: storage, forHost: "example.com")
        #expect(foundTenant_1 != nil)
        #expect(foundTenant_1?.name == "Test Tenant")

        let foundTenant_2 = Tenant.find(in: storage, forHost: "example_B.com")
        #expect(foundTenant_2 != nil)
        #expect(foundTenant_2?.name == "Second Test Tenant")
    }

    @Test func cantFindTenant() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        storage.tenants.removeAll()
        let tenant = Tenant(ref: .file(temporaryFile), name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let notFoundTenant = Tenant.find(in: storage, forHost: "not-existing.com")
        #expect(notFoundTenant == nil)
    }

    // MARK: - find by Name

    @Test func findTenantByName() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        storage.tenants.removeAll()
        let tenant = Tenant(ref: .file(temporaryFile), name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let foundTenant = Tenant.find(in: storage, name: "Test Tenant")
        #expect(foundTenant != nil)
        #expect(foundTenant?.name == "Test Tenant")
    }

    // MARK: - find by reference

    @Test func findTenantByReference() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        storage.tenants.removeAll()
        let tenant = Tenant(ref: .file(temporaryFile), name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let foundTenant = Tenant.find(in: storage, ref: .file(temporaryFile))
        #expect(foundTenant != nil)
        #expect(foundTenant?.name == "Test Tenant")
    }

    @Test func notFindTenantByReference() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        let filename = String.random(length: 10).appending(".yaml")
        let nonExistingNewFile: URL = temporaryDirectory.appendingPathComponent(filename)
        let notFoundTenant = Tenant.find(in: storage, ref: .file(nonExistingNewFile))
        #expect(notFoundTenant == nil)
    }

}
