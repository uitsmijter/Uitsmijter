@testable import Server
import XCTVapor

final class TenantTests: XCTestCase {
    var app: Application!
    var entities: EntityLoader?

    let temporaryDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(String.random(length: 10))

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

        entities = try? EntityLoader(storage: EntityStorage.shared)

        entities?.storage.tenants.removeAll()
        entities?.storage.clients.removeAll()
    }

    override func tearDown() {
        app.shutdown()
        super.tearDown()
    }

    func testConstructTenant() async throws {
        let tenant = Tenant(name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        XCTAssertEqual(tenant.name, "Test Tenant")
        XCTAssertEqual(tenant.config.hosts.count, 1)
    }

    func testAddTenants() async throws {
        guard let entities else {
            throw TestError.fail(withError: "Test setup did not initialized a entity loader.")
        }

        let tenant = Tenant(name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))

        entities.addEntity(entity: tenant)
        XCTAssertGreaterThanOrEqual(EntityStorage.shared.tenants.count, 1)
        XCTAssertEqual(EntityStorage.shared.tenants.first?.name, "Test Tenant")
    }

    func testTestEquality() async throws {
        let tenant_A = Tenant(name: "Test Tenant 1", config: TenantSpec(hosts: ["example.com"]))
        let tenant_A2 = Tenant(name: "Test Tenant 1", config: TenantSpec(hosts: ["example.net"]))
        let tenant_B = Tenant(name: "Test Tenant 2", config: TenantSpec(hosts: ["example.org"]))

        XCTAssertFalse(tenant_A == tenant_B)
        XCTAssertTrue(tenant_A == tenant_A)
        XCTAssertTrue(tenant_B == tenant_B)
        XCTAssertTrue(tenant_A == tenant_A2)
    }

    func testCanNotInsertWithSameHostDeprecated() async throws {
        guard let entities else {
            throw TestError.fail(withError: "Test setup did not initialized a entity loader.")
        }

        let tenant_A = Tenant(name: "Test Tenant 1", config: TenantSpec(hosts: ["example.com"]))
        let tenant_B = Tenant(name: "Test Tenant 2", config: TenantSpec(hosts: ["example.com"]))

        let (inserted_A, _) = entities.storage.tenants.insert(tenant_A)
        XCTAssertTrue(inserted_A)
        XCTAssertEqual(entities.storage.tenants.count, 1)

        let (inserted_B, _) = entities.storage.tenants.insert(tenant_B)
        XCTAssertFalse(inserted_B)
        XCTAssertEqual(entities.storage.tenants.count, 1)
    }

    func testCanNotAddWithSameHost() async throws {
        guard let entities else {
            XCTFail("entities not loaded")
            throw TestError.abort
        }
        let tenant_A = Tenant(name: "Test Tenant 1", config: TenantSpec(hosts: ["example.com"]))
        let tenant_B = Tenant(name: "Test Tenant 2", config: TenantSpec(hosts: ["example.com"]))

        let insertedFirst = entities.addEntity(entity: tenant_A)
        XCTAssertTrue(insertedFirst)
        XCTAssertEqual(entities.storage.tenants.count, 1)

        let insertedSecond = entities.addEntity(entity: tenant_B)
        XCTAssertFalse(insertedSecond)
        XCTAssertEqual(entities.storage.tenants.count, 1)
    }

    func testAddTenantLogAppearOnce() async throws {
        guard let entities else {
            XCTFail("entities not loaded")
            throw TestError.abort
        }

        let expectation = expectation(description: "Wait for tenant creation")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        entities.storage.hook = { type, entity in
            if type == .tenant && entity?.name == "Test Tenant AppearOnce" {
                expectation.fulfill()
            }
        }
        let tenant = Tenant(name: "Test Tenant AppearOnce", config: TenantSpec(hosts: ["add-me.example.com"]))
        entities.addEntity(entity: tenant)

        // wait for hook
        wait(for: [expectation], timeout: TestDefaults.waitTimeout)
        entities.storage.hook = nil

        XCTAssertEqual(entities.storage.tenants.count, 1)

        // test log

        let logMessages = LogWriter.logBuffer.pop(amount: LogWriter.logBuffer.count)?.map { logMessage in
            logMessage.message
        }
        // this does not work when you run `swift test` use `./tooling.sh test` instead.
        let messagesLookingFor = logMessages?.filter { msg in
            let expectedString = "Add new tenant '\(tenant.name)' with \(tenant.config.hosts.count) hosts"
            return msg.contains(expectedString)
        }
        #if os(Linux)
        XCTAssertEqual(messagesLookingFor?.count, 1)
        #endif
    }

    func testRemoveTenantLogAppearOnce() async throws {
        guard let entities else {
            XCTFail("entities not loaded")
            throw TestError.abort
        }

        let tenant = Tenant(
                ref: .kubernetes(UUID(), "1337"),
                name: "Test Tenant AppearOnce For Removal",
                config: TenantSpec(hosts: ["remove-me.example.com"])
        )
        entities.addEntity(entity: tenant)
        // try await Task.sleep(nanoseconds: 1)

        let expectation = expectation(description: "Test Tenant AppearOnce For Removal")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        entities.storage.hook = { type, entity in
            if type == .tenant && entity?.name == "Test Tenant AppearOnce For Removal" {
                expectation.fulfill()
            }
        }

        entities.removeEntity(entity: tenant)
        // entities.storage.hook = nil

        // wait for hook
        wait(for: [expectation], timeout: TestDefaults.waitTimeout)
        entities.storage.hook = nil

        XCTAssertEqual(entities.storage.tenants.count, 0)

        // test log
        let logMessages = LogWriter.logBuffer.pop(amount: LogWriter.logBuffer.count)?.map { logMessage in
            return logMessage.message
        }
        let messagesLookingFor = logMessages?.filter { msg in
            msg.contains("Remove tenant '\(tenant.name)'")
        }
        // this does not work when you run `swift test` use `./tooling.sh test` instead.
        #if os(Linux)
        XCTAssertEqual(messagesLookingFor?.count, 1)
        #endif
    }
}
