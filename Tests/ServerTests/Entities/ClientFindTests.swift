@testable import Server
import XCTVapor

final class ClientFindTests: XCTestCase {

    var tenant: Tenant?
    var temporaryDirectory: URL = FileManager.default.temporaryDirectory
    var temporaryFile: URL?

    override func setUp() {
        EntityStorage.shared.tenants.removeAll()
        EntityStorage.shared.clients.removeAll()

        let filename = String.random(length: 10).appending(".yaml")
        temporaryFile = temporaryDirectory.appendingPathComponent(filename)
        guard let temporaryFile else {
            return XCTFail("temporaryFile not present. Test setup failure")
        }

        tenant = Tenant(name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        guard let localTenant = tenant else {
            XCTFail("Can not get tenant")
            return
        }

        let (inserted, _) = EntityStorage.shared.tenants.insert(localTenant)
        XCTAssertTrue(inserted)

        let client = Client(
                ref: .file(temporaryFile),
                name: "First Client",
                config: ClientSpec(
                        ident: UUID(),
                        tenantname: localTenant.name,
                        redirect_urls: [
                            ".*\\.example\\.(org|com)",
                            "foo\\.example\\.com",
                            "wikipedia.org"
                        ],
                        scopes: ["read"],
                        referrers: [
                            "example.com"
                        ]
                )
        )
        EntityStorage.shared.clients = [client]
    }

    // MARK: - find by name

    func testFindClientByName() async throws {
        guard let tenant else {
            throw TestError.fail(withError: "No tenant available")
        }
        let foundClient = Client.find(name: "First Client", tenant: tenant)
        XCTAssertNotNil(foundClient)
        XCTAssertEqual(foundClient?.name, "First Client")
    }

    func testNotFindClientByName() async throws {
        guard let tenant else {
            throw TestError.fail(withError: "No tenant available")
        }
        let notFoundClient = Client.find(name: "Client does not exists", tenant: tenant)
        XCTAssertNil(notFoundClient)
    }

    // MARK: - find by reference

    func testFindClientByReference() async throws {
        guard let temporaryFile else {
            XCTFail("temporaryFile not present. Most likely a Test `setUp` failure")
            throw TestError.abort
        }

        let foundClient = Client.find(ref: .file(temporaryFile))
        XCTAssertNotNil(foundClient)
        XCTAssertEqual(foundClient?.name, "First Client")
    }

    func testNotFindClientByReference() async throws {
        let filename = String.random(length: 10).appending(".yaml")
        let nonExistingNewFile: URL = temporaryDirectory.appendingPathComponent(filename)
        let notFoundClient = Client.find(ref: .file(nonExistingNewFile))
        XCTAssertNil(notFoundClient)
    }
}
