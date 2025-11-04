import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Template Login Tests", .serialized)
struct TemplateLoginTest {

    let testAppIdent = UUID()

    @Test("Template with login returns correct path")
    func withLogin() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            let code = try await authorisationCodeGrantFlow(app: app, clientIdent: testAppIdent)
            let tokenResponse = try await getToken(for: code, app: app)

            let request = Request(application: app, on: app.eventLoopGroup.any())
            request.headers = [
                "Authorisation": "Bearer \(tokenResponse.access_token)",
                "X-Forwarded-Host": "localhost"
            ]

            request.clientInfo = await SharedClientInfo.clientInfo(on: request)

            let result = Template.getPath(page: "index", request: request)
            #expect(result == "default/index")
        }
    }

    // MARK: - Privates

    private func getToken(for code: String, app: Application) async throws -> TokenResponse {
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
        return try response.content.decode(TokenResponse.self)
    }
}
