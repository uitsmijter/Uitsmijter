@testable import Server
import XCTVapor

final class TenantFindWildcardTests: XCTestCase {

    var temporaryDirectory: URL = FileManager.default.temporaryDirectory
    var temporaryFile: URL?

    override func setUp() {
        let filename = String.random(length: 10).appending(".yaml")
        temporaryFile = temporaryDirectory.appendingPathComponent(filename)
        guard let temporaryFile else {
            return XCTFail("temporaryFile not present. Test setup failure")
        }

        EntityStorage.shared.tenants.removeAll()
        let tenant = Tenant(ref: .file(temporaryFile), name: "egg-tenant", config: TenantSpec(hosts: ["*.egg.example.com"]))
        let (inserted, _) = EntityStorage.shared.tenants.insert(tenant)
        XCTAssertTrue(inserted)
    }

    // MARK: - find by Host

    func testFindTenantByHost() async throws {
        let foundTenant = Tenant.find(forHost: "yolk.egg.example.com")
        XCTAssertNotNil(foundTenant)
        XCTAssertEqual(foundTenant?.name, "egg-tenant")
    }

}
