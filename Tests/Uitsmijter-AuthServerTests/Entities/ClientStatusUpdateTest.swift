import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@MainActor
@Suite("Client Status Update Tests")
struct ClientStatusUpdateTest {

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

    @Test("Session count increases after refresh token creation for client")
    func sessionCountIncreasesAfterRefreshToken() async throws {
        // Setup tenant, client, and auth code storage
        let tenant = try createTenant(tenantname: "test-tenant")
        let client = try createClient(clientName: "test-client", tenantName: tenant.name)
        let storage = AuthCodeStorage(use: .memory)

        // Initially, there should be no sessions
        let initialCount = await storage.count(client: client, type: .refresh)
        #expect(initialCount == 0)

        // Create a refresh token session with client in audience
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
            scopes: ["openid", "profile"],
            payload: payload,
            redirect: "https://example.com/callback",
            ttl: (Int64(Constants.TOKEN.REFRESH_EXPIRATION_IN_HOURS) * 60 * 60)
        )

        try await storage.set(authSession: refreshSession)

        // After creating a refresh token, count should be 1
        let afterCount = await storage.count(client: client, type: .refresh)
        #expect(afterCount == 1)
    }

    @Test("Session count is client-specific")
    func sessionCountIsClientSpecific() async throws {
        // Setup one tenant with two different clients
        let tenant = try createTenant(tenantname: "test-tenant")
        let client1 = try createClient(clientName: "client-1", tenantName: tenant.name)
        let client2 = try createClient(clientName: "client-2", tenantName: tenant.name)
        let storage = AuthCodeStorage(use: .memory)

        // Create sessions for client1
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
                user: "testuser\(index)",
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

            try await storage.set(authSession: refreshSession)
        }

        // Create sessions for client2
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
                user: "testuser\(index)",
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

            try await storage.set(authSession: refreshSession)
        }

        // Verify client-specific counts
        let client1Count = await storage.count(client: client1, type: .refresh)
        let client2Count = await storage.count(client: client2, type: .refresh)

        #expect(client1Count == 2)
        #expect(client2Count == 3)
    }

    @Test("Session count handles multiple clients in audience")
    func sessionCountHandlesMultipleClientsInAudience() async throws {
        // Setup tenant with two clients
        let tenant = try createTenant(tenantname: "test-tenant")
        let client1 = try createClient(clientName: "client-1", tenantName: tenant.name)
        let client2 = try createClient(clientName: "client-2", tenantName: tenant.name)
        let storage = AuthCodeStorage(use: .memory)

        // Create a session with both clients in audience
        let payload = Payload(
            issuer: IssuerClaim(value: "test-issuer"),
            subject: SubjectClaim(value: "test-user"),
            audience: AudienceClaim(value: [client1.config.ident.uuidString, client2.config.ident.uuidString]),
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

        try await storage.set(authSession: refreshSession)

        // Both clients should count the same session
        let client1Count = await storage.count(client: client1, type: .refresh)
        let client2Count = await storage.count(client: client2, type: .refresh)

        #expect(client1Count == 1)
        #expect(client2Count == 1)
    }

    @Test("Only refresh tokens are counted for client, not authorization codes")
    func onlyRefreshTokensCounted() async throws {
        // Setup tenant, client, and storage
        let tenant = try createTenant(tenantname: "test-tenant")
        let client = try createClient(clientName: "test-client", tenantName: tenant.name)
        let storage = AuthCodeStorage(use: .memory)

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

        // Create authorization code (should NOT be counted in refresh count)
        let authCodeSession = AuthSession(
            type: .code,
            state: "auth-state",
            code: Code(),
            scopes: ["openid"],
            payload: payload,
            redirect: "https://example.com/callback",
            ttl: 600
        )
        try await storage.set(authSession: authCodeSession)

        // Create refresh token (should be counted)
        let refreshSession = AuthSession(
            type: .refresh,
            state: "refresh-state",
            code: Code(),
            scopes: ["openid"],
            payload: payload,
            redirect: "https://example.com/callback",
            ttl: (Int64(Constants.TOKEN.REFRESH_EXPIRATION_IN_HOURS) * 60 * 60)
        )
        try await storage.set(authSession: refreshSession)

        // Only refresh tokens should be counted
        let refreshCount = await storage.count(client: client, type: .refresh)
        let codeCount = await storage.count(client: client, type: .code)

        #expect(refreshCount == 1)
        #expect(codeCount == 1)
    }

    @Test("Denied login attempts tracking for client")
    func deniedLoginAttemptsTracking() async throws {
        // Setup entity storage
        let entityStorage = EntityStorage()

        // Create a test client
        let client = try createClient(clientName: "test-client", tenantName: "test-tenant")

        // Initially, denied attempts should be 0
        let initialCount = entityStorage.getDeniedAttempts(for: client.name)
        #expect(initialCount == 0)

        // Increment denied attempts
        entityStorage.incrementDeniedAttempts(for: client.name)
        entityStorage.incrementDeniedAttempts(for: client.name)
        entityStorage.incrementDeniedAttempts(for: client.name)

        // Check count
        let afterCount = entityStorage.getDeniedAttempts(for: client.name)
        #expect(afterCount == 3)
    }

    @Test("Denied login attempts are client-specific")
    func deniedLoginAttemptsAreClientSpecific() async throws {
        // Setup entity storage
        let entityStorage = EntityStorage()

        // Create two test clients
        let client1 = try createClient(clientName: "client-1", tenantName: "test-tenant")
        let client2 = try createClient(clientName: "client-2", tenantName: "test-tenant")

        // Increment for client1
        entityStorage.incrementDeniedAttempts(for: client1.name)
        entityStorage.incrementDeniedAttempts(for: client1.name)

        // Increment for client2
        entityStorage.incrementDeniedAttempts(for: client2.name)

        // Check counts are separate
        let client1Count = entityStorage.getDeniedAttempts(for: client1.name)
        let client2Count = entityStorage.getDeniedAttempts(for: client2.name)

        #expect(client1Count == 2)
        #expect(client2Count == 1)
    }

}
