import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@Suite("Login Performance Tests", .serialized)
struct LoginPerformanceTest {
    let testAppIdent = UUID()
    let iterationCount = 100

    @Test("Complete OAuth flow performance - 100 iterations")
    func completeOAuthFlowPerformance() async throws {
        try await withApp(configure: configure) { app in
            // Setup test client and tenant
            await generateTestClient(
                in: app.entityStorage,
                uuid: testAppIdent,
                script: .johnDoe,
                scopes: ["read", "write", "list"]
            )

            // Warmup run to initialize caches, connections, etc.
            _ = try await performSingleOAuthFlow(app: app)

            // Track start time
            let startTime = Date()
            var successfulIterations = 0

            // Perform the complete OAuth flow 100 times
            for iteration in 1...iterationCount {
                do {
                    try await performSingleOAuthFlow(app: app)
                    successfulIterations += 1
                } catch {
                    Issue.record("Iteration \(iteration) failed: \(error)")
                    throw error
                }
            }

            // Calculate duration
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let averageTimePerIteration = duration / Double(iterationCount)

            // Verify all iterations succeeded
            #expect(successfulIterations == iterationCount)

            // Performance expectations
            // Each complete flow (login -> code -> token -> validate -> logout) should complete
            // in a reasonable time. Setting expectation to 500ms per iteration average.
            // This allows for some overhead but ensures performance doesn't degrade.
            let maxAverageTime: TimeInterval = 0.5 // 500ms per iteration
            let maxTotalTime: TimeInterval = Double(iterationCount) * maxAverageTime

            print("Performance Results:")
            print("  Total iterations: \(successfulIterations)")
            print("  Total time: \(String(format: "%.2f", duration))s")
            print("  Average time per iteration: \(String(format: "%.2f", averageTimePerIteration * 1000))ms")
            print("  Expected max average: \(String(format: "%.2f", maxAverageTime * 1000))ms")

            // Assert performance expectations
            #expect(
                duration < maxTotalTime,
                """
                Total time \(String(format: "%.2f", duration))s exceeded maximum expected \
                time \(String(format: "%.2f", maxTotalTime))s
                """
            )
            #expect(
                averageTimePerIteration < maxAverageTime,
                """
                Average time per iteration \(String(format: "%.2f", averageTimePerIteration * 1000))ms \
                exceeded maximum \(String(format: "%.2f", maxAverageTime * 1000))ms
                """
            )
        }
    }

    /// Performs a single complete OAuth flow: login -> authorize -> code -> token -> validate -> logout
    /// - Parameter app: The Vapor application instance
    /// - Returns: The duration of the flow in seconds
    @discardableResult
    private func performSingleOAuthFlow(app: Application) async throws -> TimeInterval {
        let flowStartTime = Date()

        // Step 1: Get authorization code through the complete flow
        let code = try await authorisationCodeGrantFlow(
            app: app,
            clientIdent: testAppIdent,
            scopes: ["read", "write"]
        )

        #expect(!code.isEmpty)
        #expect(code.count == 16)

        // Step 2: Exchange code for access token
        let tokenResponse = try await getToken(app: app, for: code, appIdent: testAppIdent)

        #expect(tokenResponse.access_token.isEmpty == false)
        #expect(tokenResponse.refresh_token != nil)
        #expect(tokenResponse.token_type == .Bearer)

        // Step 3: Validate the token
        let accessToken = tokenResponse.access_token
        let payload = try await SignerManager.shared.verify(accessToken, as: Payload.self)

        #expect(payload.user == "valid_user")
        #expect(payload.role == "default")
        #expect(payload.subject.value.isEmpty == false)

        // Step 4: Logout
        let logoutResponse = try await app.sendRequest(
            .GET,
            "logout/finalize",
            beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: accessToken)
            }
        )

        #expect(logoutResponse.status == .seeOther)
        #expect(logoutResponse.headers["location"].first == "/")
        #expect(
            logoutResponse.headers["set-cookie"]
                .filter({ $0.contains(Constants.COOKIE.NAME) })
                .first?.contains("\(Constants.COOKIE.NAME)=invalid") ?? false
        )

        let flowEndTime = Date()
        return flowEndTime.timeIntervalSince(flowStartTime)
    }

    @Test("Complete OAuth flow with refresh token - 100 iterations")
    func completeOAuthFlowWithRefreshPerformance() async throws {
        try await withApp(configure: configure) { app in
            // Setup test client and tenant with refresh token support
            await generateTestClient(
                in: app.entityStorage,
                uuid: testAppIdent,
                script: .johnDoe,
                scopes: ["read", "write", "list"],
                grantTypes: [.authorization_code, .refresh_token]
            )

            // Warmup run
            _ = try await performOAuthFlowWithRefresh(app: app)

            // Track start time
            let startTime = Date()
            var successfulIterations = 0

            // Perform the complete OAuth flow with refresh 100 times
            for iteration in 1...iterationCount {
                do {
                    try await performOAuthFlowWithRefresh(app: app)
                    successfulIterations += 1
                } catch {
                    Issue.record("Iteration \(iteration) failed: \(error)")
                    throw error
                }
            }

            // Calculate duration
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let averageTimePerIteration = duration / Double(iterationCount)

            // Verify all iterations succeeded
            #expect(successfulIterations == iterationCount)

            // Performance expectations - refresh flow should be similar to regular flow
            let maxAverageTime: TimeInterval = 0.6 // 600ms per iteration (slightly higher due to refresh)
            let maxTotalTime: TimeInterval = Double(iterationCount) * maxAverageTime

            print("Performance Results (with refresh):")
            print("  Total iterations: \(successfulIterations)")
            print("  Total time: \(String(format: "%.2f", duration))s")
            print("  Average time per iteration: \(String(format: "%.2f", averageTimePerIteration * 1000))ms")
            print("  Expected max average: \(String(format: "%.2f", maxAverageTime * 1000))ms")

            // Assert performance expectations
            #expect(
                duration < maxTotalTime,
                """
                Total time \(String(format: "%.2f", duration))s exceeded maximum expected \
                time \(String(format: "%.2f", maxTotalTime))s
                """
            )
            #expect(
                averageTimePerIteration < maxAverageTime,
                """
                Average time per iteration \(String(format: "%.2f", averageTimePerIteration * 1000))ms \
                exceeded maximum \(String(format: "%.2f", maxAverageTime * 1000))ms
                """
            )
        }
    }

    /// Performs OAuth flow with token refresh
    @discardableResult
    private func performOAuthFlowWithRefresh(app: Application) async throws -> TimeInterval {
        let flowStartTime = Date()

        // Step 1: Get authorization code
        let code = try await authorisationCodeGrantFlow(
            app: app,
            clientIdent: testAppIdent,
            scopes: ["read", "write"]
        )

        // Step 2: Exchange code for access token
        let tokenResponse = try await getToken(app: app, for: code, appIdent: testAppIdent)
        #expect(tokenResponse.refresh_token != nil)

        // Step 3: Use refresh token to get new access token
        guard let refreshToken = tokenResponse.refresh_token else {
            Issue.record("No refresh token received")
            throw TestError.abort
        }

        let refreshResponse = try await app.sendRequest(
            .POST,
            "/token",
            beforeRequest: { @Sendable req async throws in
                let refreshRequest = RefreshTokenRequest(
                    grant_type: .refresh_token,
                    client_id: testAppIdent.uuidString,
                    client_secret: nil,
                    refresh_token: refreshToken
                )
                try req.content.encode(refreshRequest, as: .json)
                req.headers.contentType = .json
            }
        )

        #expect(refreshResponse.status == .ok)
        let newTokenResponse = try refreshResponse.content.decode(TokenResponse.self)
        #expect(newTokenResponse.access_token.isEmpty == false)

        // Step 4: Validate the new token
        let newAccessToken = newTokenResponse.access_token
        let payload = try await SignerManager.shared.verify(newAccessToken, as: Payload.self)
        #expect(payload.user == "valid_user")

        // Step 5: Logout
        let logoutResponse = try await app.sendRequest(
            .GET,
            "logout/finalize",
            beforeRequest: { @Sendable req async throws in
                req.headers.bearerAuthorization = BearerAuthorization(token: newAccessToken)
            }
        )

        #expect(logoutResponse.status == .seeOther)

        let flowEndTime = Date()
        return flowEndTime.timeIntervalSince(flowStartTime)
    }
}
