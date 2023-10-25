@testable import Server
import XCTVapor

final class TenantFindTests: XCTestCase {

    var temporaryDirectory: URL = FileManager.default.temporaryDirectory
    var temporaryFile: URL?

    override func setUp() {
        let filename = String.random(length: 10).appending(".yaml")
        temporaryFile = temporaryDirectory.appendingPathComponent(filename)
        guard let temporaryFile else {
            return XCTFail("temporaryFile not present. Test setup failure")
        }

        EntityStorage.shared.tenants.removeAll()
        let tenant = Tenant(ref: .file(temporaryFile), name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = EntityStorage.shared.tenants.insert(tenant)
        XCTAssertTrue(inserted)
    }

    // MARK: - find by Host

    func testFindTenantByHost() async throws {
        let foundTenant = Tenant.find(forHost: "example.com")
        XCTAssertNotNil(foundTenant)
        XCTAssertEqual(foundTenant?.name, "Test Tenant")
    }

    func testFindWithMoreHostsTenant() async throws {
        let tenant = Tenant(
                name: "Second Test Tenant",
                config: TenantSpec(hosts: ["example_A.com", "example_B.com", "example_C.com"])
        )
        let (inserted, _) = EntityStorage.shared.tenants.insert(tenant)
        XCTAssertTrue(inserted)

        let foundTenant_1 = Tenant.find(forHost: "example.com")
        XCTAssertNotNil(foundTenant_1)
        XCTAssertEqual(foundTenant_1?.name, "Test Tenant")

        let foundTenant_2 = Tenant.find(forHost: "example_B.com")
        XCTAssertNotNil(foundTenant_2)
        XCTAssertEqual(foundTenant_2?.name, "Second Test Tenant")
    }

    func testCantFindTenant() async throws {
        let notFoundTenant = Tenant.find(forHost: "not-existing.com")
        XCTAssertNil(notFoundTenant)
    }

    // MARK: - find by Name

    func testFindTenantByName() async throws {
        let foundTenant = Tenant.find(name: "Test Tenant")
        XCTAssertNotNil(foundTenant)
        XCTAssertEqual(foundTenant?.name, "Test Tenant")
    }

    // MARK: - find by reference

    func testFindTenantByReference() async throws {
        guard let temporaryFile else {
            XCTFail("temporaryFile not present. Most likely a Test `setUp` failure")
            throw TestError.abort
        }

        let foundTenant = Tenant.find(ref: .file(temporaryFile))
        XCTAssertNotNil(foundTenant)
        XCTAssertEqual(foundTenant?.name, "Test Tenant")
    }

    func testNotFindTenantByReference() async throws {
        let filename = String.random(length: 10).appending(".yaml")
        let nonExistingNewFile: URL = temporaryDirectory.appendingPathComponent(filename)
        let notFoundClient = Client.find(ref: .file(nonExistingNewFile))
        XCTAssertNil(notFoundClient)
    }

}
