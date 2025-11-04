import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Auth Controller Code Unknown Flow Tests", .serialized)
struct AuthControllerCodeUnknownFlowTests {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    @Test("Code flow unknown challenge") func codeFlowUnknownChallenge() async throws {
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
                    + "&code_challenge_method=unknown",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .notImplemented)
                    #expect(res.body.string.contains("CODE_CHALLENGE_METHOD_NOT_IMPLEMENTED"))
                    #expect(res.body.string.contains("\"error\":true"))
                }
            )
        }
    }
}
