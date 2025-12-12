import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@MainActor
@Suite("Client Status Initialization Tests")
struct ClientStatusInitializationTest {

    func createTenant(tenantname: String) throws -> Tenant {
        var tenantConfig = TenantSpec(hosts: ["example.com"])
        tenantConfig.providers.append("class UserLoginProvider {}")
        return Tenant(ref: nil, name: tenantname, config: tenantConfig)
    }

    func createClient(clientName: String, tenantName: String) throws -> UitsmijterClient {
        let clientSpec = ClientSpec(
            ident: UUID(),
            tenantname: tenantName,
            redirect_urls: ["https://example.com/callback"]
        )
        return UitsmijterClient(ref: nil, name: clientName, config: clientSpec)
    }

    @Test("Client status updates after authCodeStorage initialization")
    func clientStatusUpdatesAfterStorageInit() async throws {
        // Setup tenant, client, and storage
        let tenant = try createTenant(tenantname: "test-tenant")
        let client = try createClient(clientName: "test-client", tenantName: tenant.name)
        let authStorage = AuthCodeStorage(use: .memory)
        let entityStorage = EntityStorage()

        // Add tenant and client to entity storage
        entityStorage.tenants.insert(tenant)
        entityStorage.clients.append(client)

        // Create sessions for the client BEFORE initialization
        let payload = Payload(
            issuer: IssuerClaim(value: "test-issuer"),
            subject: SubjectClaim(value: "test-user"),
            audience: AudienceClaim(value: [client.config.ident.uuidString]),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: tenant.name,
            responsibility: "test-domain",
            role: "user",
            user: "testuser",
            scope: "",
            profile: nil
        )

        let refreshSession = AuthSession(
            type: .refresh,
            state: "test-state",
            code: Code(),
            scopes: ["openid"],
            payload: payload,
            redirect: "https://example.com/callback",
            ttl: (Int64(Constants.TOKEN.REFRESH_EXPIRATION_IN_HOURS) * 60 * 60)
        )

        try await authStorage.set(authSession: refreshSession)

        // Verify session was created
        let sessionCount = await authStorage.count(client: client, type: .refresh)
        #expect(sessionCount == 1)

        // Verify denied attempts work
        entityStorage.incrementDeniedAttempts(for: client.name)
        entityStorage.incrementDeniedAttempts(for: client.name)
        let deniedCount = entityStorage.getDeniedAttempts(for: client.name)
        #expect(deniedCount == 2)
    }

    @Test("Multiple clients with different session counts")
    func multipleClientsWithDifferentSessions() async throws {
        // Setup
        let tenant = try createTenant(tenantname: "test-tenant")
        let client1 = try createClient(clientName: "client-1", tenantName: tenant.name)
        let client2 = try createClient(clientName: "client-2", tenantName: tenant.name)
        let authStorage = AuthCodeStorage(use: .memory)
        let entityStorage = EntityStorage()

        entityStorage.tenants.insert(tenant)
        entityStorage.clients.append(client1)
        entityStorage.clients.append(client2)

        // Create 2 sessions for client1
        for index in 0..<2 {
            let payload = Payload(
                issuer: IssuerClaim(value: "test-issuer"),
                subject: SubjectClaim(value: "user-\(index)"),
                audience: AudienceClaim(value: [client1.config.ident.uuidString]),
                expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                issuedAt: IssuedAtClaim(value: Date()),
                authTime: AuthTimeClaim(value: Date()),
                tenant: tenant.name,
                responsibility: "test-domain",
                role: "user",
                user: "user\(index)",
                scope: "",
                profile: nil
            )

            let refreshSession = AuthSession(
                type: .refresh,
                state: "state-\(index)",
                code: Code(),
                scopes: ["openid"],
                payload: payload,
                redirect: "https://example.com/callback",
                ttl: (Int64(Constants.TOKEN.REFRESH_EXPIRATION_IN_HOURS) * 60 * 60)
            )

            try await authStorage.set(authSession: refreshSession)
        }

        // Create 3 sessions for client2
        for index in 0..<3 {
            let payload = Payload(
                issuer: IssuerClaim(value: "test-issuer"),
                subject: SubjectClaim(value: "user-\(index)"),
                audience: AudienceClaim(value: [client2.config.ident.uuidString]),
                expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                issuedAt: IssuedAtClaim(value: Date()),
                authTime: AuthTimeClaim(value: Date()),
                tenant: tenant.name,
                responsibility: "test-domain",
                role: "user",
                user: "user\(index)",
                scope: "",
                profile: nil
            )

            let refreshSession = AuthSession(
                type: .refresh,
                state: "state-\(index)",
                code: Code(),
                scopes: ["openid"],
                payload: payload,
                redirect: "https://example.com/callback",
                ttl: (Int64(Constants.TOKEN.REFRESH_EXPIRATION_IN_HOURS) * 60 * 60)
            )

            try await authStorage.set(authSession: refreshSession)
        }

        // Set different denied counts
        entityStorage.incrementDeniedAttempts(for: client1.name)
        entityStorage.incrementDeniedAttempts(for: client2.name)
        entityStorage.incrementDeniedAttempts(for: client2.name)
        entityStorage.incrementDeniedAttempts(for: client2.name)

        // Verify counts
        let client1Sessions = await authStorage.count(client: client1, type: .refresh)
        let client2Sessions = await authStorage.count(client: client2, type: .refresh)
        let client1Denied = entityStorage.getDeniedAttempts(for: client1.name)
        let client2Denied = entityStorage.getDeniedAttempts(for: client2.name)

        #expect(client1Sessions == 2)
        #expect(client2Sessions == 3)
        #expect(client1Denied == 1)
        #expect(client2Denied == 3)
    }
}
