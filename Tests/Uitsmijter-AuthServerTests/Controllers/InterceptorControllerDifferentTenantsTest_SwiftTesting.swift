import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Interceptor Controller - Different Tenants", .serialized)
struct InterceptorDifferentTenantsSwiftTest {
    // Note: Swift Testing suites are value types (structs) so they don't have deinit
    // Resource cleanup needs to be handled explicitly in each test or with shared resources

    @Test("Interceptor should reject request with token from different tenant")
    func interceptorWithOtherTenantShouldFail() async throws {
        // Setup for this specific test
        let testAppIdent1 = UUID()
        let testAppIdent2 = UUID()

        try await withApp(configure: configure) { app in
            // Setup test clients with multiple tenants
            await generateTestClientsWithMultipleTenants(in: app.entityStorage, uuids: [testAppIdent1, testAppIdent2])

            // Get the tenants from the created clients
            guard let tenant1 = await app.entityStorage.clients
                    .first(where: { $0.config.ident == testAppIdent1 })?
                    .config.tenant(in: app.entityStorage),
                  let tenant2 = await app.entityStorage.clients
                    .first(where: { $0.config.ident == testAppIdent2 })?
                    .config.tenant(in: app.entityStorage) else {
                Issue.record("No tenant found in test setup")
                return
            }

            // Using Vapor's testable API directly to avoid XCTVapor Sendable issues
            try await app.testing().test(
                .GET,
                "interceptor",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant1, in: app)
                    req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                    req.headers.replaceOrAdd(
                        name: "X-Forwarded-Host",
                        value: tenant2.config.hosts.first ?? "_ERROR_"
                    )
                    req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
                },
                afterResponse: { @Sendable response async in
                    #expect(
                        response.status == .forbidden,
                        "Expected forbidden status when using token from different tenant"
                    )
                }
            )
        }
    }
}
