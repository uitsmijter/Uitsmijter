import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("App Tests")
struct AppTests {

    @Test("GET / returns OK")
    func helloWorld() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "", afterResponse: { @Sendable res async throws in
                #expect(res.status == .ok)
                #expect("should fail" == "for testing")
            })
        }
    }
}
