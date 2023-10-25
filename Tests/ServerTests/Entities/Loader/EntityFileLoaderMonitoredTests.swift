@testable import Server
import XCTVapor

final class EntityFileLoaderMonitoredTests: XCTestCase {
    var app: Application!
    let temporaryDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(String.random(length: 10))

    let sleepTime: UInt64 = 10_000_000

    override func setUp() {
        super.setUp()

        do {
            try FileManager.default.createDirectory(
                    at: temporaryDirectory,
                    withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                    at: temporaryDirectory.appendingPathComponent("Configurations"),
                    withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                    at: temporaryDirectory.appendingPathComponent("Configurations").appendingPathComponent("Tenants"),
                    withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                    at: temporaryDirectory.appendingPathComponent("Configurations").appendingPathComponent("Clients"),
                    withIntermediateDirectories: true
            )
        } catch {
            XCTFail(error.localizedDescription)
        }

        app = Application(.testing)
        app.directory.resourcesDirectory = temporaryDirectory.absoluteString
        try? configure(app)

        EntityStorage.shared.tenants.removeAll()
        EntityStorage.shared.clients.removeAll()
    }

    override func tearDown() {
        super.tearDown()
        app.shutdown()
    }
}

// MARK: - Tenants
extension EntityFileLoaderMonitoredTests {

    func testEmptyTenants() async throws {
        XCTAssertEqual(EntityStorage.shared.tenants.count, 0)
        XCTAssertEqual(EntityStorage.shared.clients.count, 0)
    }

    func testAddTenant() async throws {
        let tenantUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Tenants")
                .appendingPathComponent("test.yaml")

        let expectation = expectation(description: "Wait for tenant creation")
        expectation.assertForOverFulfill = false

        EntityStorage.shared.hook = { (type: ManagedEntityType, entity: Entity?) in
            if type == .tenant {
                if let reference = entity?.ref {
                    if reference.description.contains("Configurations/Tenants/test.yaml") {
                        expectation.fulfill()
                    }
                }
            }
        }

        try createTenant(tenantUrl: tenantUrl)

        wait(for: [expectation], timeout: 10)
        try await Task.sleep(nanoseconds: sleepTime)
        XCTAssertEqual(EntityStorage.shared.tenants.count, 1)
    }

    func testChangeTenant() async throws {
        let tenantUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Tenants")
                .appendingPathComponent("test.yaml")

        try await testAddTenant()

        let expectation = expectation(description: "Wait for tenant change")
        expectation.assertForOverFulfill = false
        EntityStorage.shared.hook = { (type: ManagedEntityType, entity: Entity?) in
            if type == .tenant {
                if let reference = entity?.ref {
                    if reference.description.contains("Configurations/Tenants/test.yaml") {
                        // we test here the testcase, otherwise we have to `Thread.sleep(forTimeInterval: 2)`
                        // because we also get changes that removes/added the tenant too fast
                        if (entity as? TenantProtocol)?.config.hosts.count == 2 {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }

        try """
            ---
            name: DelayedAddedTenant
            config:
              hosts:
                - localhost
                - newhost.com
              interceptor:
                enabled: false
              providers:
                - class UserLoginProvider {
                  constructor(credentials) { commit(true); }
                  get canLogin() { return true; }
                  get userProfile() { return {name:"Local Admin"}; }
                  get role() { return "normal"; }
                  }
              silent_login: false
            """.write(to: tenantUrl, atomically: false, encoding: .utf8)

        wait(for: [expectation], timeout: 10)
        try await Task.sleep(nanoseconds: sleepTime)

        XCTAssertEqual(EntityStorage.shared.tenants.count, 1)
        XCTAssertEqual(EntityStorage.shared.tenants.first?.config.hosts.count, 2)
        XCTAssertContains(EntityStorage.shared.tenants.first?.config.hosts.joined(separator: "|"), "localhost")
        XCTAssertContains(EntityStorage.shared.tenants.first?.config.hosts.joined(separator: "|"), "newhost.com")
    }

    func testDeleteTenant() async throws {
        let tenantUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Tenants")
                .appendingPathComponent("test.yaml")

        try await testAddTenant()
        XCTAssertEqual(EntityStorage.shared.tenants.count, 1)

        let expectation = expectation(description: "Wait for tenant deletion")
        expectation.assertForOverFulfill = false
        EntityStorage.shared.hook = { (type: ManagedEntityType, entity: Entity?) in
            if type == .tenant {
                if let reference = entity?.ref {
                    if reference.description.contains("Configurations/Tenants/test.yaml") {
                        expectation.fulfill()
                    }
                }
            }
        }

        try FileManager.default.removeItem(at: tenantUrl)
        wait(for: [expectation], timeout: 10)

        try await Task.sleep(nanoseconds: sleepTime)
        XCTAssertEqual(EntityStorage.shared.tenants.count, 0)
    }

    // MARK: - privates

    private func createTenant(tenantUrl: URL) throws {
        try """
            ---
            name: DelayedAddedTenant
            config:
              hosts:
                - localhost
              interceptor:
                enabled: false
              providers:
                - class UserLoginProvider {
                  constructor(credentials) { commit(true); }
                  get canLogin() { return true; }
                  get userProfile() { return {name:"Local Admin"}; }
                  get role() { return "normal"; }
                  }
              silent_login: false
            """.write(to: tenantUrl, atomically: false, encoding: .utf8)
    }
}

// MARK: - Clients
extension EntityFileLoaderMonitoredTests {

    func testAddClient() async throws {
        let tenantUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Tenants")
                .appendingPathComponent("test.yaml")

        let clientUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Clients")
                .appendingPathComponent("test.yaml")

        let tenantExpectation = expectation(description: "Wait for tenant creation")
        tenantExpectation.assertForOverFulfill = false
        let clientExpectation = expectation(description: "Wait for client creation")
        clientExpectation.assertForOverFulfill = false

        EntityStorage.shared.hook = { (type: ManagedEntityType, entity: Entity?) in
            if type == .tenant {
                tenantExpectation.fulfill()
            }
            if type == .client {
                if let reference = entity?.ref {
                    if reference.description.contains("Configurations/Clients/test.yaml") {
                        clientExpectation.fulfill()
                    }
                }
            }
        }

        let lastCount = EntityStorage.shared.clients.count

        try createTenant(tenantUrl: tenantUrl)
        wait(for: [tenantExpectation], timeout: 10)

        try createClient(clientUrl: clientUrl)
        wait(for: [clientExpectation], timeout: 10)

        try await Task.sleep(nanoseconds: sleepTime)
        XCTAssertEqual(EntityStorage.shared.clients.count, lastCount + 1)
    }

    func testChangeClient() async throws {
        let clientUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Clients")
                .appendingPathComponent("test.yaml")

        try await testAddClient()

        let expectation = expectation(description: "Wait for client change")
        expectation.assertForOverFulfill = false
        EntityStorage.shared.hook = { (type: ManagedEntityType, entity: Entity?) in
            if type == .client {
                if let reference = entity?.ref {
                    if reference.description.contains("Configurations/Clients/test.yaml") {
                        // we test here the testcase, otherwise we have to `Thread.sleep(forTimeInterval: 2)`
                        // because we also get changes to fast from removes/adds from the client
                        if (entity as? ClientProtocol)?.config.scopes?.count == 2 {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }

        try """
            ---
            name: DelayedAddedClient
            config:
              ident: 52D5AC25-FC8A-413D-88D9-D56265FA8CDE
              tenantname: DelayedAddedTenant
              redirect_urls:
                - http://localhost/.*
              scopes:
                - read
                - write
              referrers:
                - http://localhost/login
              isPkceOnly: false
            """.write(to: clientUrl, atomically: false, encoding: .utf8)

        wait(for: [expectation], timeout: 10)

        try await Task.sleep(nanoseconds: sleepTime)
        XCTAssertEqual(EntityStorage.shared.clients.count, 1)
        XCTAssertEqual(EntityStorage.shared.clients.first?.config.scopes?.count, 2)
        XCTAssertContains(EntityStorage.shared.clients.first?.config.scopes?.joined(separator: "|"), "read")
        XCTAssertContains(EntityStorage.shared.clients.first?.config.scopes?.joined(separator: "|"), "write")
    }

    func testChangeClientOtherIndent() async throws {
        let clientUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Clients")
                .appendingPathComponent("test.yaml")

        try await testAddClient()

        let expectation = expectation(description: "Wait for client change")
        expectation.assertForOverFulfill = false
        EntityStorage.shared.hook = { (type: ManagedEntityType, entity: Entity?) in
            if type == .client {
                if let reference = entity?.ref {
                    if reference.description.contains("Configurations/Clients/test.yaml") {
                        // we test here the testcase, otherwise we have to `Thread.sleep(forTimeInterval: 2)`
                        // because we also get changes to fast from removes/adds from the client
                        if (entity as? ClientProtocol)?.config.scopes?.count == 2 {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }

        try """
            ---
            name: DelayedAddedClient
            config:
                ident: 6FCC0669-B85C-4E9C-8FFB-0D6F0CE63D53
                tenantname: DelayedAddedTenant
                redirect_urls:
                  - http://localhost/.*
                scopes:
                  - read
                  - write
                referrers:
                  - http://localhost/login
                isPkceOnly: false
            """.write(to: clientUrl, atomically: false, encoding: .utf8)

        wait(for: [expectation], timeout: 10)

        try await Task.sleep(nanoseconds: sleepTime)
        XCTAssertEqual(EntityStorage.shared.clients.count, 1)
        XCTAssertEqual(EntityStorage.shared.clients.first?.config.scopes?.count, 2)
        XCTAssertContains(EntityStorage.shared.clients.first?.config.scopes?.joined(separator: "|"), "read")
        XCTAssertContains(EntityStorage.shared.clients.first?.config.scopes?.joined(separator: "|"), "write")
    }

    func testDeleteClient() async throws {
        let clientUrl = temporaryDirectory
                .appendingPathComponent("Configurations")
                .appendingPathComponent("Clients")
                .appendingPathComponent("test.yaml")

        try await testAddClient()
        XCTAssertEqual(EntityStorage.shared.clients.count, 1)

        let expectation = expectation(description: "Wait for client deletion")
        expectation.assertForOverFulfill = false
        EntityStorage.shared.hook = { (type: ManagedEntityType, entity: Entity?) in
            if type == .client {
                if entity == nil {
                    expectation.fulfill()
                }
            }
        }

        try FileManager.default.removeItem(at: clientUrl)
        wait(for: [expectation], timeout: 10)

        try await Task.sleep(nanoseconds: sleepTime)
        XCTAssertEqual(EntityStorage.shared.clients.count, 0)
    }

    // MARK: - privates

    private func createClient(clientUrl: URL) throws {
        try """
            ---
            name: DelayedAddedClient
            config:
              ident: 6CFC222C-D2BE-482F-9DA5-703E25FEF819
              tenantname: DelayedAddedTenant
              redirect_urls:
                - http://localhost/.*
              scopes:
                - all
              referrers:
                - http://localhost/login
              isPkceOnly: false
            """.write(to: clientUrl, atomically: false, encoding: .utf8)
    }
}
