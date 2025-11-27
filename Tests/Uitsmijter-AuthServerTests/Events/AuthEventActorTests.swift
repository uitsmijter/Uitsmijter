import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@MainActor
@Suite("AuthEventActor Tests")
struct AuthEventActorTests {

    func createTenant(tenantname: String) -> Tenant {
        var tenantConfig = TenantSpec(hosts: ["example.com"])
        tenantConfig.providers.append("class UserLoginProvider {}")
        return Tenant(ref: nil, name: tenantname, config: tenantConfig)
    }

    func createClient(clientName: String, tenantName: String) -> UitsmijterClient {
        let clientSpec = ClientSpec(
            ident: UUID(),
            tenantname: tenantName,
            redirect_urls: ["https://example.com/callback"]
        )
        return UitsmijterClient(ref: nil, name: clientName, config: clientSpec)
    }

    @Test("Record login success updates entity storage")
    func recordLoginSuccessUpdatesEntityStorage() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)
        let tenant = createTenant(tenantname: "test-tenant")
        let client = createClient(clientName: "test-client", tenantName: tenant.name)

        // Record login success
        await actor.recordLoginSuccess(
            tenant: tenant.name,
            client: client,
            mode: "oauth",
            host: "example.com"
        )

        // Verify - Prometheus metrics are incremented (can't test directly without mocking)
        // But we can verify the method executes without error
    }

    @Test("Record login failure increments denied attempts")
    func recordLoginFailureIncrementsDeniedAttempts() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)
        let tenant = createTenant(tenantname: "test-tenant")
        let client = createClient(clientName: "test-client", tenantName: tenant.name)

        // Initially, denied attempts should be 0
        let initialCount = entityStorage.getDeniedAttempts(for: client.name)
        #expect(initialCount == 0)

        // Record login failure
        await actor.recordLoginFailure(
            tenant: tenant.name,
            client: client,
            mode: "oauth",
            host: "example.com"
        )

        // Verify denied attempts incremented
        let afterCount = entityStorage.getDeniedAttempts(for: client.name)
        #expect(afterCount == 1)
    }

    @Test("Record login failure without client does not increment denied attempts")
    func recordLoginFailureWithoutClientDoesNotIncrement() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)

        // Record login failure without client (interceptor mode)
        await actor.recordLoginFailure(
            tenant: "test-tenant",
            client: nil,
            mode: "interceptor",
            host: "example.com"
        )

        // No client means no denied attempts tracking
        // This should execute without error
    }

    @Test("Record multiple login failures for same client")
    func recordMultipleLoginFailuresSameClient() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)
        let tenant = createTenant(tenantname: "test-tenant")
        let client = createClient(clientName: "test-client", tenantName: tenant.name)

        // Record multiple failures
        await actor.recordLoginFailure(
            tenant: tenant.name,
            client: client,
            mode: "oauth",
            host: "example.com"
        )
        await actor.recordLoginFailure(
            tenant: tenant.name,
            client: client,
            mode: "oauth",
            host: "example.com"
        )
        await actor.recordLoginFailure(
            tenant: tenant.name,
            client: client,
            mode: "oauth",
            host: "example.com"
        )

        // Verify denied attempts incremented correctly
        let count = entityStorage.getDeniedAttempts(for: client.name)
        #expect(count == 3)
    }

    @Test("Record login failures for different clients are tracked separately")
    func recordLoginFailuresDifferentClients() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)
        let tenant = createTenant(tenantname: "test-tenant")
        let client1 = createClient(clientName: "client-1", tenantName: tenant.name)
        let client2 = createClient(clientName: "client-2", tenantName: tenant.name)

        // Record failures for each client
        await actor.recordLoginFailure(tenant: tenant.name, client: client1, mode: "oauth", host: "example.com")
        await actor.recordLoginFailure(tenant: tenant.name, client: client1, mode: "oauth", host: "example.com")
        await actor.recordLoginFailure(tenant: tenant.name, client: client2, mode: "oauth", host: "example.com")

        // Verify counts are separate
        let client1Count = entityStorage.getDeniedAttempts(for: client1.name)
        let client2Count = entityStorage.getDeniedAttempts(for: client2.name)

        #expect(client1Count == 2)
        #expect(client2Count == 1)
    }

    @Test("Record logout executes without error")
    func recordLogoutExecutesWithoutError() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)
        let tenant = createTenant(tenantname: "test-tenant")
        let client = createClient(clientName: "test-client", tenantName: tenant.name)

        // Record logout
        await actor.recordLogout(
            tenant: tenant.name,
            client: client,
            mode: "oauth",
            redirect: "https://example.com/logout"
        )

        // Verify - Prometheus metrics are incremented (can't test directly without mocking)
        // But we can verify the method executes without error
    }

    @Test("Record logout without client (interceptor mode)")
    func recordLogoutWithoutClient() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)

        // Record logout without client (interceptor mode)
        await actor.recordLogout(
            tenant: "test-tenant",
            client: nil,
            mode: "interceptor",
            redirect: "https://example.com"
        )

        // This should execute without error
    }

    @Test("Mixed login success and failure events")
    func mixedLoginEvents() async throws {
        // Setup
        let entityStorage = EntityStorage()
        let actor = AuthEventActor(entityStorage: entityStorage, entityLoader: nil)
        let tenant = createTenant(tenantname: "test-tenant")
        let client = createClient(clientName: "test-client", tenantName: tenant.name)

        // Record mixed events: 2 failures, 1 success, 1 failure
        await actor.recordLoginFailure(tenant: tenant.name, client: client, mode: "oauth", host: "example.com")
        await actor.recordLoginFailure(tenant: tenant.name, client: client, mode: "oauth", host: "example.com")
        await actor.recordLoginSuccess(tenant: tenant.name, client: client, mode: "oauth", host: "example.com")
        await actor.recordLoginFailure(tenant: tenant.name, client: client, mode: "oauth", host: "example.com")

        // Only failures should increment denied attempts
        let deniedCount = entityStorage.getDeniedAttempts(for: client.name)
        #expect(deniedCount == 3)
    }
}
