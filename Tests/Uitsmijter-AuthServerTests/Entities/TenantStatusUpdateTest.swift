import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@MainActor
@Suite("Tenant Status Update Tests")
struct TenantStatusUpdateTest {

    func createTenant(tenantname: String) throws -> Tenant {
        var tenantConfig = TenantSpec(hosts: ["example.com"])
        tenantConfig.providers.append("class UserLoginProvider {}")
        return Tenant(ref: nil, name: tenantname, config: tenantConfig)
    }

    @Test("Session count increases after refresh token creation")
    func sessionCountIncreasesAfterRefreshToken() async throws {
        // Setup tenant and auth code storage
        let tenant = try createTenant(tenantname: "test-tenant")
        let storage = AuthCodeStorage(use: .memory)

        // Initially, there should be no sessions
        let initialCount = await storage.count(tenant: tenant, type: .refresh)
        #expect(initialCount == 0)

        // Create a refresh token session
        let payload = Payload(
            issuer: IssuerClaim(value: "test-issuer"),
            subject: SubjectClaim(value: "test-user"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: tenant.name,
            responsibility: "test-domain",
            role: "user",
            user: "testuser",
            scope: [], // TODO insert correct scope values
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
        let afterCount = await storage.count(tenant: tenant, type: .refresh)
        #expect(afterCount == 1)
    }

    @Test("Session count decreases after wipe")
    func sessionCountDecreasesAfterWipe() async throws {
        // Setup tenant and auth code storage
        let tenant = try createTenant(tenantname: "test-tenant")
        let storage = AuthCodeStorage(use: .memory)

        // Create multiple refresh token sessions for the same tenant
        for index in 0..<3 {
            let payload = Payload(
                issuer: IssuerClaim(value: "test-issuer"),
                subject: SubjectClaim(value: "test-user-\(index)"),
                audience: AudienceClaim(value: "test-client"),
                expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                issuedAt: IssuedAtClaim(value: Date()),
                authTime: AuthTimeClaim(value: Date()),
                tenant: tenant.name,
                responsibility: "test-domain",
                role: "user",
                user: "testuser\(index)",
                scope: [], // TODO insert correct scope values
                profile: nil
            )

            let refreshSession = AuthSession(
                type: .refresh,
                state: "test-state-\(index)",
                code: Code(),
                scopes: ["openid", "profile"],
                payload: payload,
                redirect: "https://example.com/callback",
                ttl: (Int64(Constants.TOKEN.REFRESH_EXPIRATION_IN_HOURS) * 60 * 60)
            )

            try await storage.set(authSession: refreshSession)
        }

        // Count should be 3
        let beforeWipe = await storage.count(tenant: tenant, type: .refresh)
        #expect(beforeWipe == 3)

        // Wipe sessions for one user
        await storage.wipe(tenant: tenant, subject: "test-user-1")

        // Count should be 2 now
        let afterWipe = await storage.count(tenant: tenant, type: .refresh)
        #expect(afterWipe == 2)
    }

    @Test("Session count is tenant-specific")
    func sessionCountIsTenantSpecific() async throws {
        // Setup two different tenants
        let tenant1 = try createTenant(tenantname: "tenant-1")
        let tenant2 = try createTenant(tenantname: "tenant-2")
        let storage = AuthCodeStorage(use: .memory)

        // Create sessions for tenant1
        for index in 0..<2 {
            let payload = Payload(
                issuer: IssuerClaim(value: "test-issuer"),
                subject: SubjectClaim(value: "user-\(index)"),
                audience: AudienceClaim(value: "test-client"),
                expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                issuedAt: IssuedAtClaim(value: Date()),
                authTime: AuthTimeClaim(value: Date()),
                tenant: tenant1.name,
                responsibility: "test-domain",
                role: "user",
                user: "testuser\(index)",
                scope: [], // TODO insert correct scope values
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

        // Create sessions for tenant2
        for index in 0..<3 {
            let payload = Payload(
                issuer: IssuerClaim(value: "test-issuer"),
                subject: SubjectClaim(value: "user-\(index)"),
                audience: AudienceClaim(value: "test-client"),
                expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
                issuedAt: IssuedAtClaim(value: Date()),
                authTime: AuthTimeClaim(value: Date()),
                tenant: tenant2.name,
                responsibility: "test-domain",
                role: "user",
                user: "testuser\(index)",
                scope: [], // TODO insert correct scope values
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

        // Verify tenant-specific counts
        let tenant1Count = await storage.count(tenant: tenant1, type: .refresh)
        let tenant2Count = await storage.count(tenant: tenant2, type: .refresh)

        #expect(tenant1Count == 2)
        #expect(tenant2Count == 3)
    }

    @Test("Only refresh tokens are counted, not authorization codes")
    func onlyRefreshTokensCounted() async throws {
        // Setup tenant and storage
        let tenant = try createTenant(tenantname: "test-tenant")
        let storage = AuthCodeStorage(use: .memory)

        let payload = Payload(
            issuer: IssuerClaim(value: "test-issuer"),
            subject: SubjectClaim(value: "test-user"),
            audience: AudienceClaim(value: "test-client"),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: tenant.name,
            responsibility: "test-domain",
            role: "user",
            user: "testuser",
            scope: [], // TODO insert correct scope values
            profile: nil
        )

        // Create authorization code (should NOT be counted)
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
        let refreshCount = await storage.count(tenant: tenant, type: .refresh)
        let codeCount = await storage.count(tenant: tenant, type: .code)

        #expect(refreshCount == 1)
        #expect(codeCount == 1)
    }
}
