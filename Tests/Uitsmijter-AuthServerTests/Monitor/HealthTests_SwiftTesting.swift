import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Health Endpoint Tests")
struct HealthTestsSwiftTesting {

    @Test("GET /health returns no content")
    func getHealthReturnsNoContent() async throws {
        try await withApp(configure: configure) { app in
            // Using Vapor's underlying client directly instead of XCTVapor
            try await app.testing().test(.GET, "health") { @Sendable res async throws in
                #expect(res.status == .noContent)
            }
        }
    }
}
