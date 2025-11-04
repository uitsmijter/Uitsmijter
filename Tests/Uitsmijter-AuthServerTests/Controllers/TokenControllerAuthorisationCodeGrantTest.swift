import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@Suite("Token Controller Authorisation Code Grant Test", .serialized)
struct TokenControllerAuthorisationCodeGrantTest {
    let testAppIdent = UUID()

    @Test("Token controller authorisation code grant wrong code")
    func tokenControllerAuthorisationCodeGrantWrongCode() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage, uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"]
            )
            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: "not-a-valid-code").value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .forbidden)
        }
    }

    // without scopes

    @Test("Token controller authorisation code grant")
    func tokenControllerAuthorisationCodeGrant() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage, uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"]
            )

            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)

            // -----------------------------------
            // Get authorisation code
            // -----------------------------------
            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })

            #expect(response.status == .ok)
            let tokenResponse = try response.content.decode(TokenResponse.self)
            #expect(tokenResponse.scope?.isEmpty == true)
            #expect(tokenResponse.refresh_token != nil)

            let jwt = tokenResponse.access_token
            #expect(tokenResponse.scope == "")

            let payload = try jwt_signer.verify(jwt, as: Payload.self)
            #expect(payload.user == "valid_user")
            #expect(payload.role == "default")
        }
    }

    // with scopes

    @Test("Token controller authorisation code grant with scopes")
    func tokenControllerAuthorisationCodeGrantWithScopes() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(
                in: app.entityStorage, uuid: testAppIdent, script: .johnDoe, scopes: ["read", "list"]
            )

            let code = try await authorisationCodeGrantFlow(
                app: app,
                clientIdent: testAppIdent,
                scopes: ["list", "write", "read", "admin"]
            )

            // -----------------------------------
            // 5b. get authorisation code
            // -----------------------------------
            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    scope: "list admin read",
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })

            #expect(response.status == .ok)
            let tokenResponse = try response.content.decode(TokenResponse.self)
            #expect((tokenResponse.scope?.count ?? 0) > 0)
            #expect(tokenResponse.refresh_token != nil)

            let jwt = tokenResponse.access_token
            #expect(tokenResponse.scope?.contains("list") == true)
            #expect(tokenResponse.scope?.contains("read") == true)

            let payload = try jwt_signer.verify(jwt, as: Payload.self)
            #expect(payload.user == "valid_user")
            #expect(payload.role == "default")
        }
    }

    // Explicit allowed or not

    @Test("Token controller authorisation code grant allowed")
    func tokenControllerAuthorisationCodeGrantAllowed() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.authorization_code],
                script: .johnDoe,
                scopes: ["read", "list"]
            )

            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)

            // -----------------------------------
            // Get authorisation code
            // -----------------------------------
            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })

            #expect(response.status == .ok)
        }
    }

    @Test("Token controller authorisation code grant not allowed")
    func tokenControllerAuthorisationCodeGrantNotAllowed() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.password],
                script: .johnDoe,
                scopes: ["read", "list"]
            )

            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)

            // -----------------------------------
            // Get authorisation code
            // -----------------------------------
            let testAppIdentString = testAppIdent.uuidString
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdentString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })

            #expect(response.status == .badRequest)
        }
    }

}
