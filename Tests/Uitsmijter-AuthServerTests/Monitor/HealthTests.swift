import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Health Endpoint Tests")
struct HealthTests {

    @Test("GET /health returns no content")
    func getHealth() async throws {
        try await withApp(configure: configure) { app in

            try await app.testing().test(.GET, "health", afterResponse: { @Sendable res async throws in
                #expect(res.status == .noContent)
            })
        }
    }
}
