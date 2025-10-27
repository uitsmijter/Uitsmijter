import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@MainActor
@Suite(.serialized) struct ClientFindTests {

    // MARK: - find by name

    @Test func findClientByName() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        storage.tenants.removeAll()
        storage.clients.removeAll()

        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        let tenant = Tenant(name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let client = Client(
            ref: .file(temporaryFile),
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
        storage.clients = [client]

        let foundClient = Client.find(in: storage, name: "First Client", tenant: tenant)
        #expect(foundClient != nil)
        #expect(foundClient?.name == "First Client")
    }

    @Test func notFindClientByName() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        storage.tenants.removeAll()
        storage.clients.removeAll()

        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        let tenant = Tenant(name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let client = Client(
            ref: .file(temporaryFile),
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
        storage.clients = [client]

        let notFoundClient = Client.find(in: storage, name: "Client does not exists", tenant: tenant)
        #expect(notFoundClient == nil)
    }

    // MARK: - find by reference

    @Test func findClientByReference() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        storage.tenants.removeAll()
        storage.clients.removeAll()

        let filename = String.random(length: 10).appending(".yaml")
        guard let temporaryFile = temporaryDirectory.appendingPathComponent(filename) as URL? else {
            Issue.record("temporaryFile not present. Test setup failure")
            return
        }

        let tenant = Tenant(name: "Test Tenant", config: TenantSpec(hosts: ["example.com"]))
        let (inserted, _) = storage.tenants.insert(tenant)
        #expect(inserted)

        let client = Client(
            ref: .file(temporaryFile),
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
        storage.clients = [client]

        let foundClient = Client.find(in: storage, ref: .file(temporaryFile))
        #expect(foundClient != nil)
        #expect(foundClient?.name == "First Client")
    }

    @Test func notFindClientByReference() async throws {
        let storage = EntityStorage()
        let temporaryDirectory: URL = FileManager.default.temporaryDirectory
        let filename = String.random(length: 10).appending(".yaml")
        let nonExistingNewFile: URL = temporaryDirectory.appendingPathComponent(filename)
        let notFoundClient = Client.find(in: storage, ref: .file(nonExistingNewFile))
        #expect(notFoundClient == nil)
    }
}
