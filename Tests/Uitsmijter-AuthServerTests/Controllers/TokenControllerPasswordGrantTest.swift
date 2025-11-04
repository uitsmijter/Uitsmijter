import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Token Controller Password Grant Tests", .serialized)
struct TokenControllerPasswordGrantTest {
    let testAppIdent = UUID()

    @Test("Password grant with wrong password returns forbidden")
    func tokenControllerPasswordGrantWrongPass() async throws {
        #if compiler(<6.1)
        #expect(Bool(false), "Test requires Swift 6.1 or later")
        #else
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.authorization_code, .refresh_token, .password],
                script: .johnDoe
            )

            try await app.testing().test(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = PasswordTokenRequest(
                        grant_type: .password,
                        client_id: testAppIdent.uuidString,
                        client_secret: nil,
                        username: "valid_user",
                        password: "not_correct"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                },
                afterResponse: { @Sendable response async in
                    #expect(response.status == .forbidden)
                }
            )
        }
        #endif
    }

    @Test("Password grant with wrong user returns forbidden")
    func tokenControllerPasswordGrantWrongUser() async throws {
        #if compiler(<6.1)
        #expect(Bool(false), "Test requires Swift 6.1 or later")
        #else
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.authorization_code, .refresh_token, .password],
                script: .johnDoe
            )

            try await app.testing().test(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = PasswordTokenRequest(
                        grant_type: .password,
                        client_id: testAppIdent.uuidString,
                        client_secret: nil,
                        username: "Gustav",
                        password: "valid_password"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                },
                afterResponse: { @Sendable response async in
                    #expect(response.status == .forbidden)
                }
            )
        }
        #endif
    }

    @Test("Password grant with correct credentials returns token")
    func tokenControllerPasswordGrantCorrectCredentials() async throws {
        #if compiler(<6.1)
        #expect(Bool(false), "Test requires Swift 6.1 or later")
        #else
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.authorization_code, .refresh_token, .password],
                script: .johnDoe
            )

            try await app.testing().test(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = PasswordTokenRequest(
                        grant_type: .password,
                        client_id: testAppIdent.uuidString,
                        client_secret: nil,
                        username: "valid_user",
                        password: "valid_password"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                },
                afterResponse: { @Sendable response async in
                    #expect(response.status == .ok)

                    guard let content = try? response.content.decode(TokenResponse.self) else {
                        Issue.record("Failed to decode TokenResponse")
                        return
                    }

                    #expect(content.scope == "")
                    #expect(content.token_type == .Bearer)

                    guard let expires_in = content.expires_in else {
                        Issue.record("Expires in is missing but expected")
                        return
                    }

                    #expect(expires_in / 60 / 60 == Constants.TOKEN.EXPIRATION_HOURS)
                    #expect(content.access_token.count > 64)
                    // tokens issued with the implicit grant cannot be issued a refresh token.
                    #expect(content.refresh_token == nil)
                }
            )
        }
        #endif
    }

    @Test("Password grant with correct credentials and scopes returns token with scope")
    func tokenControllerPasswordGrantCorrectCredentialsWithScopes() async throws {
        #if compiler(<6.1)
        #expect(Bool(false), "Test requires Swift 6.1 or later")
        #else
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.authorization_code, .refresh_token, .password],
                script: .johnDoe
            )

            try await app.testing().test(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = PasswordTokenRequest(
                        grant_type: .password,
                        client_id: testAppIdent.uuidString,
                        client_secret: nil,
                        scope: "read",
                        username: "valid_user",
                        password: "valid_password"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                },
                afterResponse: { @Sendable response async in
                    #expect(response.status == .ok)

                    guard let content = try? response.content.decode(TokenResponse.self) else {
                        Issue.record("Failed to decode TokenResponse")
                        return
                    }

                    #expect(content.scope == "read")
                    #expect(content.token_type == .Bearer)

                    guard let expires_in = content.expires_in else {
                        Issue.record("Expires in is missing but expected")
                        return
                    }

                    #expect(expires_in / 60 / 60 == Constants.TOKEN.EXPIRATION_HOURS)
                    #expect(content.access_token.count > 64)
                    // tokens issued with the implicit grant cannot be issued a refresh token.
                    #expect(content.refresh_token == nil)
                }
            )
        }
        #endif
    }
}
