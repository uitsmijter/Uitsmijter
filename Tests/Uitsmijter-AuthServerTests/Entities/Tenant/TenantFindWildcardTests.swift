import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@MainActor
@Suite(.serialized) struct TenantFindWildcardTests {

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
        let tenant = Tenant(
            ref: .file(temporaryFile),
            name: "egg-tenant",
            config: TenantSpec(hosts: ["*.egg.example.com"])
        )
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let foundTenant = Tenant.find(in: storage, forHost: "yolk.egg.example.com")
        #expect(foundTenant != nil)
        #expect(foundTenant?.name == "egg-tenant")
    }

}
