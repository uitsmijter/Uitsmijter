import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Interceptor Controller Tests", .serialized)
struct InterceptorControllerTest {
    let testAppIdent = UUID()

    @Test("Interceptor without valid token should forward to login")
    func interceptorWithoutValidTokenShouldForwardToLogin() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            guard (await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?
                .config.tenant(in: app.entityStorage)) != nil
            else {
                Issue.record("Can not get tenant.")
                return
            }

            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: "Unknown")
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: "127.0.0.1")
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .temporaryRedirect)
                #expect(
                    response.headers.first(name: "location")?
                        .contains("http://localhost:8080/login?for=http://127.0.0.1/test") == true
                )
            })
        }
    }

    @Test("Interceptor without valid host for tenant should fail")
    func interceptorWithoutValidHostForTenantShouldFail() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?
                .config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant.")
                return
            }

            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: "10.0.0.1")
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .badRequest)
            })
        }
    }

    @Test("Interceptor with valid token should forward to target")
    func interceptorWithValidTokenShouldForwardToTarget() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?
                .config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant.")
                return
            }

            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: tenant.config.hosts.first ?? "_ERROR_")
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .ok)
                #expect(response.headers.setCookie == nil)
            })
        }
    }

    @Test("Interceptor with valid token should renew token")
    func interceptorWithValidTokenShouldRenewToken() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?
                .config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant.")
                return
            }

            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                // Create a token that expires in less than 2 hours to trigger renewal
                // Token expires 7 days after creation, so we create it 7 days - 1.5 hours ago
                let dateInPast = Calendar.current.date(
                    byAdding: .hour,
                    value: -(7 * 24 - 1),  // Almost 7 days ago, leaving ~1 hour until expiration
                    to: Date()
                )

                #expect(Date() > (dateInPast ?? Date()))
                req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app, now: dateInPast)
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: tenant.config.hosts.first ?? "_ERROR_")
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async throws in
                #expect(response.status == .ok)
                #expect(response.headers.setCookie != nil)

                guard let cookie: HTTPCookies = response.headers.setCookie else {
                    throw TestError.fail(withError: "No cookies in header")
                }
                #expect(cookie.all["uitsmijter-sso"]?.domain == "127.0.0.1")
                #expect(cookie.all["uitsmijter-sso"]?.path == "/")
                #expect((cookie.all["uitsmijter-sso"]?.string.count ?? 0) > 32)
            })
        }
    }
}
