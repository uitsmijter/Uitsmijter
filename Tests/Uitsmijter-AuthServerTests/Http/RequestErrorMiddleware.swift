import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Request Error Middleware Tests", .serialized)
struct RequestErrorMiddlewareTest {

    @Test("GET HTML error returns 404 with HTML content type")
    func getHTMLError() async throws {
        try await withApp(configure: configure) { app in
            var headers = HTTPHeaders()
            headers.add(name: "Accept", value: "text/html")
            try await app.testing().test(
                .GET,
                "/not-found",
                headers: headers,
                afterResponse: { @Sendable response async throws in
                    #expect(response.status.code == 404)
                    #expect(response.headers.contentType == HTTPMediaType.html)
                })
        }
    }

    @Test("GET JSON error returns 404 with JSON content type")
    func getJSONError() async throws {
        try await withApp(configure: configure) { app in
            var headers = HTTPHeaders()
            headers.add(name: "Accept", value: "application/json")
            try await app.testing().test(
                .GET,
                "/not-found",
                headers: headers,
                afterResponse: { @Sendable response async throws in
                    #expect(response.status.code == 404)
                    #expect(response.headers.contentType == HTTPMediaType.json)
                })
        }
    }
}
