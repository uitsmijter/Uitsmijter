import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Auth Controller Code Client With Secret Test", .serialized)
struct AuthControllerCodeClientWithSecretTest {
    let testAppIdent = UUID()
    let testSecret = String.random(length: 12)

    // MARK: - Insecure

    @Test("Code flow ensure client")
    func codeFlowEnsureClient() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent, secret: testSecret)
            // get the tenant to save the id into the Payload
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&client_secret=\(testSecret)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .seeOther)
                }
            )
        }
    }

    @Test("Code flow no client secret") func codeFlowNoClientSecret() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent, secret: testSecret)
            guard let tenant = await app.entityStorage.clients.first(
                where: { $0.config.ident == testAppIdent }
            )?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .unauthorized)
                }
            )
        }
    }

    @Test("Code flow wrong client secret") func codeFlowWrongClientSecret() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent, secret: testSecret)
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&client_secret=_I_AM_NOT_SET"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .unauthorized)
                }
            )
        }
    }

    // MARK: - Plain

    @Test("Code flow ensure client plain") func codeFlowEnsureClientPlain() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent, secret: testSecret)
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&client_secret=\(testSecret)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "&code_challenge_method=plain"
                    + "&code_challenge=hello-world",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .seeOther)
                }
            )
        }
    }

    @Test("Code flow no client secret plain") func codeFlowNoClientSecretPlain() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent, secret: testSecret)
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "&code_challenge_method=plain"
                    + "&code_challenge=hello-world",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .unauthorized)
                }
            )
        }
    }

    @Test("Code flow wrong client secret plain") func codeFlowWrongClientSecretPlain() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent, secret: testSecret)
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?.config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&client_secret=_I_AM_NOT_SET"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "&code_challenge_method=plain"
                    + "&code_challenge=hello-world",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .unauthorized)
                }
            )
        }
    }
}
