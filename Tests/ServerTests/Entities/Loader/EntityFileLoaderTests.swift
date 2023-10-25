@testable import Server
import XCTVapor

final class EntityFileLoaderTests: XCTestCase {
    var app: Application!
    var stubsPath: URL!

    override func setUp() {
        super.setUp()

        app = Application(.testing)
        stubsPath = URL(
                string: "Tests/ServerTests/Entities/Loader/Stubs/",
                relativeTo: URL(string: app.directory.workingDirectory)
        )
        app.directory.resourcesDirectory = stubsPath.absoluteString
        try? configure(app)

        EntityStorage.shared.tenants.removeAll()
        EntityStorage.shared.clients.removeAll()
    }

    override func tearDown() {
        app.shutdown()
        super.tearDown()
    }

    func testListYamls() async throws {
        let efl = try EntityFileLoader(handler: nil)

        guard let yamlDirectory = URL(string: "Yaml/", relativeTo: stubsPath) else {
            XCTFail("Directory for test files not found")
            throw TestError.abort
        }

        let files = try efl.listYamls(in: yamlDirectory)
        XCTAssertEqual(files.count, 2)
    }

    func testListYamlsIgnoreOther() async throws {
        let efl = try EntityFileLoader(handler: nil)

        guard let yamlDirectory = URL(string: "NotYaml/", relativeTo: stubsPath) else {
            XCTFail("Directory for test files not found")
            throw TestError.abort
        }
        let files = try efl.listYamls(in: yamlDirectory)

        XCTAssertEqual(files.count, 0)
    }

    func testLoadEntityEmptyDir() async throws {
        // The dir must contain .gitkeep files but they are ignored by listYamls
        guard let emptyStubsPath = URL(
                string: "Tests/ServerTests/Entities/Loader/Stubs/Empty/",
                relativeTo: URL(string: app.directory.workingDirectory)
        )
        else {
            XCTFail("Errors in getting emptyStubsPath.")
            throw TestError.abort
        }
        app.directory.resourcesDirectory = emptyStubsPath.absoluteString

        _ = try EntityFileLoader(handler: nil)

        let tenants = EntityStorage.shared.tenants
        let clients = EntityStorage.shared.clients

        XCTAssertEqual(0, tenants.count)
        XCTAssertEqual(0, clients.count)
    }

    func testLoadEntityStubs() async throws {
        struct AddEntityHandler: EntityLoaderProtocolFunctions {
            @discardableResult func addEntity(entity: Entity) -> Bool {
                switch entity {
                case let tenant as UitsmijterTenant:
                    EntityStorage.shared.tenants.insert(tenant)
                case let client as UitsmijterClient:
                    EntityStorage.shared.clients.append(client)
                default:
                    Log.error("Can not add entity, because the type is unhandled.")
                }
                return true
            }

            func removeEntity(entity: Entity) {
                print("not implemented")
            }
        }

        _ = try EntityFileLoader(handler: AddEntityHandler())

        let tenants = EntityStorage.shared.tenants
        let clients = EntityStorage.shared.clients

        XCTAssertEqual(tenants.count, 1)
        guard let tenant = tenants.first else {
            XCTFail("No first tenant found.")
            throw TestError.abort
        }

        XCTAssertEqual(tenant.name, "StubTenant")
        XCTAssertEqual(tenant.config.hosts[0], "localhost")
        XCTAssertTrue(tenant.config.interceptor?.enabled == true)
        XCTAssertTrue(tenant.config.silent_login == false)
        XCTAssertEqual(tenant.config.informations?.imprint_url, "https://page.localhost/imprint")

        XCTAssertNotNil(tenant.config.templates)
        XCTAssertEqual(tenant.config.templates?.access_key_id, "someS3Id")
        XCTAssertEqual(tenant.config.templates?.secret_access_key, "superSecretK3y")
        XCTAssertEqual(tenant.config.templates?.host, "s3.localhost")
        XCTAssertEqual(tenant.config.templates?.bucket, "stub")
        XCTAssertEqual(tenant.config.templates?.path, "templates")
        XCTAssertEqual(tenant.config.templates?.region, "stubby-1")

        XCTAssertEqual(clients.count, 1)
        guard let client = clients.first else {
            XCTFail("No first client found.")
            throw TestError.abort
        }
        XCTAssertEqual(client.name, "StubClient")
        XCTAssertEqual(client.config.tenantname, "StubTenant")
        XCTAssertEqual(client.config.tenant?.name, "StubTenant")
        XCTAssertNotEqual(client.config.ident.uuidString, "")

        switch client.ref {
        case .file(let url):
            XCTAssertContains(url.path, "Configurations/Clients/StubClient.yaml")
        default:
            XCTFail("Reference is not a file")
        }
    }
}
