@testable import Uitsmijter_AuthServer
import Testing
import VaporTesting

@Suite("Login Controller Form Tests", .serialized)
struct LoginControllerFormTests {

    @Test("Get login page")
    func getLoginPage() async throws {
        try await withApp(configure: configure) { app in

            try await app.testing().test(.GET, "login", afterResponse: { @Sendable res async throws in
                #expect(res.status == .ok)
                #expect(res.body.string.contains("form"))
                #expect(res.body.string.contains("name=\"username\""))
                #expect(res.body.string.contains("name=\"password\""))
            })
        }
    }

}
