import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Interceptor Controller Not Configured In Client Tests", .serialized)
struct InterceptorControllerNotConfiguredInClientTest {
    let testAppIdent = UUID()

    @Test("Interceptor on tenant without interceptor settings forward to target")
    func interceptorOnTenantWithoutInterceptorSettingsForwardToTarget() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            guard let tenant = await app.entityStorage.clients.first(
                where: { $0.config.ident == testAppIdent }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("No tenant")
                return
            }

            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                if let hostHeaderValue = tenant.config.hosts.first {
                    req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: hostHeaderValue)
                }
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async in
                #expect(response.status == .ok)
                #expect(response.headers.setCookie == nil)
            })
        }
    }

    @Test("Interceptor on tenant with interceptor settings true forward to target")
    func interceptorOnTenantWithInterceptorSettingsTrueForwardToTarget() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage,
                uuid: testAppIdent,
                includeGrantTypes: [.interceptor, .password]
            )
            guard let tenant = await app.entityStorage.clients.first(
                where: { $0.config.ident == testAppIdent }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("No tenant")
                return
            }

            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                if let hostHeaderValue = tenant.config.interceptor?.domain {
                    req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: hostHeaderValue)
                }
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async in
                #expect(response.status == .ok)
                #expect(response.headers.setCookie == nil)
            })
        }
    }

    @Test("Interceptor on tenant with interceptor settings false forward to login")
    func interceptorOnTenantWithInterceptorSettingsFalseForwardToLogin() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent, includeGrantTypes: [.password])
            guard let tenant = await app.entityStorage.clients.first(
                where: { $0.config.ident == testAppIdent }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("No tenant")
                return
            }

            try await app.testing().test(.GET, "interceptor", beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
                if let hostHeaderValue = tenant.config.hosts.first {
                    req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: hostHeaderValue)
                }
                req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
            }, afterResponse: { @Sendable response async in
                #expect(response.status == .forbidden)
            })
        }
    }
}
