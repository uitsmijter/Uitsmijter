import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Auth Controller Referer Tests", .serialized)
struct AuthControllerRefererTests {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    @Test("Redirect to login page OK") func redirectToLoginPageOK() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent, referrers: ["http://localhost:8080/"])
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "response_mode=query",
                beforeRequest: { @Sendable req async throws in
                    req.headers.add(name: "Referer", value: "http://localhost:8080/foo")
                }, afterResponse: { @Sendable response async throws in
                    #expect(response.status == .unauthorized)
                    #expect(response.body.string.contains("action=\"/login\""))
                })
        }
    }

    @Test("Redirect to login page fail") func redirectToLoginPageFail() async throws {
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent, referrers: ["http://localhost:8080/"])
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=\(testAppIdent.uuidString)"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123"
                    + "response_mode=query",
                beforeRequest: { @Sendable req async throws in
                    req.headers.add(name: "Referer", value: "http://evilhackerssite/hoho")
                }, afterResponse: { @Sendable response async throws in
                    #expect(response.status == .forbidden)
                    #expect(response.body.string.contains("WRONG_REFERER"))
                })
        }
    }

}
