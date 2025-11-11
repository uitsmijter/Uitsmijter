import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Auth Controller Code Insecure Flow Test", .serialized)
struct AuthControllerCodeInsecureFlowTest {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    @Test("Valid users code flow plain without specification")
    func validUsersCodeFlowPlainWithoutSpecification() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
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
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    let contentLength = res.headers["content-length"].first
                    #expect(contentLength == "0")

                    // check location
                    let location = res.headers["location"].first
                    #expect(location?.contains("http://localhost/?code=") == true)
                    let locationParts = location?.components(separatedBy: "?")
                    let parameters = locationParts?[1].components(separatedBy: "&")
                    let codeParameter = parameters?.filter({ $0.contains("code=") })
                    let codeParameterPair = codeParameter?.first?.components(separatedBy: "=")
                    let codeValue = codeParameterPair?[1]

                    // check code requirements
                    #expect(codeValue != nil)
                    #expect(codeValue?.count == 16)

                    // check cookie
                    //                    let cookie = res.headers["set-cookie"].first
                    //                    #expect(cookie?.contains("uitsmijter=") == true)
                    //                    #expect(cookie?.contains("Max-Age=") == true)
                    //                    #expect(cookie?.contains("Path=/") == true)
                    //                    #expect(cookie?.contains("SameSite=Strict") == true)

                    // check status and location header presence
                    #expect(res.status == .seeOther)
                    #expect(location != nil, "Location header must be present for redirect")

                    // be sure that it can be used
                    guard let codeValue else {
                        Issue.record("Code is nil")
                        return
                    }
                    let response = try await app.sendRequest(
                        .POST, "/token", beforeRequest: { @Sendable req async throws in
                        let tokenRequest = CodeTokenRequest(
                            grant_type: .authorization_code,
                            client_id: testAppIdent.uuidString,
                            client_secret: nil,
                            scope: nil,
                            code: Code(value: codeValue).value
                        )
                        try req.content.encode(tokenRequest, as: .json)
                        req.headers.contentType = .json
                        })
                    #expect(response.status == .ok)
                    let accessToken = try? response.content.decode(TokenResponse.self)
                    #expect(accessToken?.access_token != nil)
                    #expect(accessToken?.refresh_token != nil)
                }
            )
        }
    }

    @Test("Unknown users code flow none explicit specification not logged in")
    func unknownUsersCodeFlowNoneExplicitSpecificationNotLoggedIn() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "&code_challenge_method=none",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = BearerAuthorization(token: "Unknown")
                },
                afterResponse: { @Sendable res async throws in
                    let contentLength = res.headers["content-length"].first
                    #expect((Int16(contentLength ?? "0") ?? 0) > 0)
                    #expect(res.body.string.contains("login"))
                    #expect(res.body.string.contains("username"))
                    #expect(res.body.string.contains("type=\"password\""))
                    #expect(res.body.string.contains("submit"))
                }
            )
        }
    }

    @Test("Valid users code flow plain explicit specification")
    func validUsersCodeFlowPlainExplicitSpecification() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)
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
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "&code_challenge_method=none",
                beforeRequest: { @Sendable req async throws in
                    req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
                },
                afterResponse: { @Sendable res async throws in
                    let contentLength = res.headers["content-length"].first
                    #expect(contentLength == "0")

                    // check location
                    let location = res.headers["location"].first
                    #expect(location?.contains("http://localhost/?code=") == true)
                    let locationParts = location?.components(separatedBy: "?")
                    let parameters = locationParts?[1].components(separatedBy: "&")
                    let codeParameter = parameters?.filter({ $0.contains("code=") })
                    let codeParameterPair = codeParameter?.first?.components(separatedBy: "=")
                    let codeValue = codeParameterPair?[1]

                    // check code requirements
                    #expect(codeValue != nil)
                    #expect(codeValue?.count == 16)

                    // check cookie
                    //                    let cookie = res.headers["set-cookie"].first
                    //                    #expect(cookie?.contains("uitsmijter=") == true)
                    //                    #expect(cookie?.contains("Max-Age=") == true)
                    //                    #expect(cookie?.contains("Path=/") == true)
                    //                    #expect(cookie?.contains("SameSite=Strict") == true)

                    // check status and location header presence
                    #expect(res.status == .seeOther)
                    #expect(location != nil, "Location header must be present for redirect")

                    // be sure that it can be used
                    guard let codeValue else {
                        Issue.record("Code is nil")
                        return
                    }
                    let response = try await app.sendRequest(
                        .POST, "/token", beforeRequest: { @Sendable req async throws in
                        let tokenRequest = CodeTokenRequest(
                            grant_type: .authorization_code,
                            client_id: testAppIdent.uuidString,
                            client_secret: nil,
                            scope: nil,
                            code: Code(value: codeValue).value
                        )
                        try req.content.encode(tokenRequest, as: .json)
                        req.headers.contentType = .json
                        })
                    #expect(response.status == .ok)
                    let accessToken = try response.content.decode(TokenResponse.self)
                    #expect(accessToken.access_token.isEmpty == false)
                    #expect(accessToken.refresh_token != nil)
                }
            )
        }
    }

}
