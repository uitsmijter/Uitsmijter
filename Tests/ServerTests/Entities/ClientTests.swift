@testable import Server
import XCTVapor

final class ClientTests: XCTestCase {
    var app: Application!
    var entities: EntityLoader?

    let temporaryDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(String.random(length: 10))

    private func getClient(tenant: Tenant) -> UitsmijterClient {
        Client(
                ref: .file(FileManager.default.temporaryDirectory.appendingPathComponent("_test.yaml")),
                name: "First Client",
                config: ClientSpec(
                        ident: UUID(),
                        tenantname: tenant.name,
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
    }

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

    func testConstructAndAddClient() async throws {
        guard let entities else {
            throw TestError.fail(withError: "Test setup did not initialized a entity loader.")
        }

        let tenant = Tenant(name: "ClientTests Tenant", config: TenantSpec(hosts: ["client-test.com"]))
        XCTAssertTrue(entities.storage.tenants.insert(tenant).inserted)

        let client = getClient(tenant: tenant)

        entities.addEntity(entity: client)
        XCTAssertEqual(entities.storage.clients.count, 1)
        XCTAssertEqual(client.name, "First Client")
        XCTAssertEqual(client.config.scopes?.count, 1)
        XCTAssertEqual(client.config.scopes?.first, "read")
        XCTAssertContains(client.config.redirect_urls.joined(separator: ".."), "foo\\.example\\.com")

        // Double check the entity
        guard let first = entities.storage.clients.first else {
            XCTFail("Should not happen at all")
            throw TestError.abort
        }
        XCTAssertEqual(first.name, "First Client")
    }

    func testAddClientLogAppearOnce() async throws {
        guard let entities else {
            throw TestError.fail(withError: "Test setup did not initialized a entity loader.")
        }

        let tenant = Tenant(name: "ClientTests Tenant", config: TenantSpec(hosts: ["client-test.com"]))
        XCTAssertTrue(entities.storage.tenants.insert(tenant).inserted)
        let client = getClient(tenant: tenant)

        let expectation = expectation(description: "Wait for client creation")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        entities.storage.hook = { type, _ in
            if type == .client {
                expectation.fulfill()
            }
        }

        entities.addEntity(entity: client)

        // wait for hook
        wait(for: [expectation], timeout: 10)
        entities.storage.hook = nil

        XCTAssertEqual(entities.storage.clients.count, 1)

        // test log
        let logMessages = LogWriter.logBuffer.pop(amount: LogWriter.logBuffer.count)?.map { logMessage in
            logMessage.message
        }
        let messagesLookingFor = logMessages?.filter { msg in
            let expectedString = "Add new client '\(client.name)' [\(client.config.ident)] "
                    .appending("for tenant '\(client.config.tenant!.name)'") // swiftlint:disable:this force_unwrapping
            return msg.contains(expectedString)
        }
        XCTAssertEqual(messagesLookingFor?.count, 1)
    }

    func testRemoveClientLogAppearOnce() async throws {
        guard let entities else {
            throw TestError.fail(withError: "Test setup did not initialized a entity loader.")
        }

        let tenant = Tenant(name: "ClientTests Tenant", config: TenantSpec(hosts: ["client-test.com"]))
        XCTAssertTrue(entities.storage.tenants.insert(tenant).inserted)
        let client = getClient(tenant: tenant)

        entities.addEntity(entity: client)
        try await Task.sleep(nanoseconds: 1)

        let expectation = expectation(description: "Wait for client deletion")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        entities.storage.hook = { type, _ in
            if type == .client {
                expectation.fulfill()
            }
        }

        entities.removeEntity(entity: client)

        // wait for hook
        wait(for: [expectation], timeout: 10)
        entities.storage.hook = nil
        XCTAssertEqual(entities.storage.clients.count, 0)

        // test log
        let logMessages = LogWriter.logBuffer.pop(amount: LogWriter.logBuffer.count)?.map { logMessage in
            logMessage.message
        }
        let messagesLookingFor = logMessages?.filter { logMessages in
            let expectedString = "Remove client '\(client.name)' [\(client.config.ident)] "
                    .appending("from tenant '\(client.config.tenant!.name)'") // swiftlint:disable:this force_unwrapping
            return logMessages.contains(expectedString)
        }
        XCTAssertEqual(messagesLookingFor?.count, 1)
    }

}
