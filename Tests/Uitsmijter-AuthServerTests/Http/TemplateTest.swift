import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Template Tests")
struct TemplateTest {

    let testAppIdent = UUID()

    @Test("Template without login returns error")
    func withoutLogin() async throws {
        let app = try await Application.make(.testing)
        await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
        try? await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "-"]
        request.clientInfo = await SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "index", request: request)
        #expect(result == "default/error")

        try await app.asyncShutdown()
    }

    @Test("Template with header fallback to default")
    func withHeaderFallbackToDefault() async throws {
        let app = try await Application.make(.testing)
        await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
        try? await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "example.com"]
        request.clientInfo = await SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "index", request: request)
        #expect(result == "default/index")

        try await app.asyncShutdown()
    }

    @Test("Template with unknown header returns error")
    func withUnknownHeader() async throws {
        let app = try await Application.make(.testing)
        await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
        try? await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "example.org"]
        request.clientInfo = await SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "index", request: request)
        #expect(result == "default/error")

        try await app.asyncShutdown()
    }

    @Test("Template with header to unknown page fallback to default")
    func withHeaderToUnknownFallbackToDefault() async throws {
        let app = try await Application.make(.testing)
        await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
        try? await configure(app)

        let request = Request(application: app, on: app.eventLoopGroup.any())
        request.headers = ["X-Forwarded-Host": "example.com"]
        request.clientInfo = await SharedClientInfo.clientInfo(on: request)

        let result = Template.getPath(page: "not_exists", request: request)
        #expect(result == "default/index")

        try await app.asyncShutdown()
    }

    // MARK: - Privates

    private func getToken(for code: String) async throws -> TokenResponse {
        let app = try await Application.make(.testing)
        await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
        try? await configure(app)

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
        let tokenResponse = try response.content.decode(TokenResponse.self)

        try await app.asyncShutdown()
        return tokenResponse
    }
}
