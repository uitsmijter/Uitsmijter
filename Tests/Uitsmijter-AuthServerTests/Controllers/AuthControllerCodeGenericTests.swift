import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Auth Controller Code Generic Tests", .serialized)
struct AuthControllerCodeGenericTests {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    @Test("Code flow without parameters should fail")
    func codeFlowWithoutParametersShouldFail() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            try await app.testing().test(.GET, "authorize", afterResponse: { @Sendable res async throws in
                let err = try decoder.decode(ResponseError.self, from: res.body)
                #expect(res.status == .badRequest)
                #expect(err.reason.contains("No String was found at 'response_type'"))
            })
        }
    }

    @Test("Unknown code challenge should fail")
    func unknownCodeChallengeShouldFail() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let response = try await app.sendRequest(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "&code_challenge_method=nonexistent",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "Unknown")
                }
            )
            #expect(response.status == .notImplemented)
        }
    }

    @Test("With wrong code should fail")
    func withWrongCodeShouldFail() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            _ = try await getCode(
                in: app.entityStorage,
                application: app,
                clientUUID: testAppIdent,
                challenge: "",
                method: .none
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: "________________").value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .forbidden)
        }
    }

    @Test("Should not use a code twice")
    func shouldNotUseACodeTwice() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await getCode(
                in: app.entityStorage,
                application: app,
                clientUUID: testAppIdent,
                challenge: "",
                method: .none
            )
            let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
            })
            #expect(response.status == .ok)
            let accessToken = try response.content.decode(TokenResponse.self)
            #expect(accessToken.token_type == .Bearer)

            let secondResponse = try await app.sendRequest(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                let tokenRequest = CodeTokenRequest(
                    grant_type: .authorization_code,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    scope: nil,
                    code: Code(value: code).value
                )
                try req.content.encode(tokenRequest, as: .json)
                req.headers.contentType = .json
                })
            #expect(secondResponse.status == .forbidden)
        }
    }
}
