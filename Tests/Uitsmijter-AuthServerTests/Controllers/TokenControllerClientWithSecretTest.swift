import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Token Controller - Client with Secret", .serialized)
struct TokenControllerClientWithSecretTest {

    // MARK: - Password Flow

    /// We only need to test password in the first place, because client check happens right at the beginning.
    /// For further versions other types should be checked too, in case of some refactoring

    @Test("Token password flow ensures client secret is valid")
    func tokenPasswordFlowEnsureClient() async throws {
        // Setup for this specific test
        let testAppIdent = UUID()
        let testSecret = String.random(length: 12)

        try await withApp(configure: configure) { app in
            // Setup test client with secret
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.password],
                secret: testSecret,
                script: .johnDoe
            )

            // Using Vapor's testable API directly to avoid XCTVapor Sendable issues
            try await app.testing().test(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = PasswordTokenRequest(
                        grant_type: .password,
                        client_id: testAppIdent.uuidString,
                        client_secret: testSecret,
                        username: "valid_user",
                        password: "valid_password"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                },
                afterResponse: { @Sendable response async throws in
                    #expect(response.status == .ok)
                    let content = try response.content.decode(TokenResponse.self)
                    #expect(content.scope == "")
                    #expect(content.token_type == .Bearer)
                    #expect((content.expires_in ?? 0) / 60 / 60 == Constants.TOKEN.EXPIRATION_HOURS)
                    #expect(content.access_token.count > 64)
                }
            )
        }
    }

    @Test("Password flow without client secret should be unauthorized")
    func passwordFlowNoClientSecret() async throws {
        // Setup for this specific test
        let testAppIdent = UUID()
        let testSecret = String.random(length: 12)

        try await withApp(configure: configure) { app in
            // Setup test client with secret
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.password],
                secret: testSecret,
                script: .johnDoe
            )

            // Using Vapor's testable API directly to avoid XCTVapor Sendable issues
            try await app.testing().test(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = PasswordTokenRequest(
                        grant_type: .password,
                        client_id: testAppIdent.uuidString,
                        username: "valid_user",
                        password: "valid_password"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                },
                afterResponse: { @Sendable response async in
                    #expect(response.status == .unauthorized)
                }
            )
        }
    }

    @Test("Password flow with wrong client secret should be unauthorized")
    func passwordFlowWrongClientSecret() async throws {
        // Setup for this specific test
        let testAppIdent = UUID()
        let testSecret = String.random(length: 12)

        try await withApp(configure: configure) { app in
            // Setup test client with secret
            await generateTestClientWithSecret(in: app.entityStorage, uuid: testAppIdent,
                includeGrantTypes: [.password],
                secret: testSecret,
                script: .johnDoe
            )

            // Using Vapor's testable API directly to avoid XCTVapor Sendable issues
            try await app.testing().test(
                .POST,
                "/token",
                beforeRequest: { @Sendable req async throws in
                    let tokenRequest = PasswordTokenRequest(
                        grant_type: .password,
                        client_id: testAppIdent.uuidString,
                        client_secret: "_I_AM_WRONG_IN_ANY_CIRCUMSTANCES",
                        username: "valid_user",
                        password: "valid_password"
                    )
                    try req.content.encode(tokenRequest, as: .json)
                    req.headers.contentType = .json
                },
                afterResponse: { @Sendable response async in
                    #expect(response.status == .unauthorized)
                }
            )
        }
    }
}
