import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Interceptor Controller Different Tenants Tests", .serialized)
struct InterceptorControllerDifferentTenantsTest {
    let testAppIdent1 = UUID()
    let testAppIdent2 = UUID()

    @Test("Interceptor with other tenant should fail")
    func interceptorWithOtherTenantShouldFail() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientsWithMultipleTenants(
                in: app.entityStorage,
                uuids: [testAppIdent1, testAppIdent2]
            )
            let tenant1 = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent1 })?
                .config.tenant(in: app.entityStorage)
            let tenant2 = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent2 })?
                .config.tenant(in: app.entityStorage)
            guard let tenant1, let tenant2 else {
                Issue.record("No tenant")
                return
            }
            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = try validAuthorisation(for: tenant1, in: app)
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: tenant2.config.hosts.first ?? "_ERROR_")
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .forbidden)
            })
        }
    }

}
