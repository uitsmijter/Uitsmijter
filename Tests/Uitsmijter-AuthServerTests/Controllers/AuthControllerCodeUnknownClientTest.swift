import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Auth Controller Code Unknown Client Test", .serialized)
struct AuthControllerCodeUnknownClientTest {
    let testAppIdent = UUID()

    @Test("Code flow ensure client")
    func codeFlowEnsureClient() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            // get the tenant to save the id into the Payload
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?
                .config.tenant(in: app.entityStorage)
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
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .seeOther)
                }
            )
        }
    }

    @Test("Code flow unknown client JSON")
    func codeFlowUnknownClientJSON() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            // get the tenant to save the id into the Payload
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?
                .config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            let newClientIdent = UUID()
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(newClientIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.headers.contentType == HTTPMediaType.json)
                    #expect(res.status == .badRequest)
                    #expect(res.body.string.contains("\"error\":true"))
                    #expect(res.body.string.contains("LOGIN.ERRORS.NO_CLIENT"))
                    #expect(res.body.string.starts(with: "{")) // is a json object
                }
            )
        }
    }

    @Test("Code flow unknown client HTML")
    func codeFlowUnknownClientHTML() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            // get the tenant to save the id into the Payload
            guard let tenant = await app.entityStorage.clients
                .first(where: { $0.config.ident == testAppIdent })?
                .config.tenant(in: app.entityStorage)
            else {
                Issue.record("Can not get tenant")
                return
            }

            let newClientIdent = UUID()
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(newClientIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.add(name: "Accept", value: "text/html")
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.headers.contentType == HTTPMediaType.html)
                    #expect(res.status == .badRequest)
                    #expect(res.body.string.contains("<html"))
                    #expect(res.body.string.contains("<title>Error | 400</title>"))
                    #expect(res.body.string.contains("class=\"error-headline\""))
                }
            )
        }
    }
}
