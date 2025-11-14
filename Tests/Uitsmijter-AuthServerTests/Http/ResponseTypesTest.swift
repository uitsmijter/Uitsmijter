import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Response Types Tests", .serialized)
struct ResponseTypesTest {

    // MARK: - Login

    @Test("GET /login with HTML content type returns HTML")
    func getLoginWeb() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "login",
                beforeRequest: { @Sendable req async throws in
                    req.headers.contentType = .html
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)
                    #expect(res.headers.contentType == HTTPMediaType.html)
                }
            )
        }
    }

    @Test("GET /login with default content type returns HTML")
    func getLoginDefault() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "login",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)
                    // Default content type is HTML when no Accept header is specified
                    #expect(res.headers.contentType == HTTPMediaType.html)
                }
            )
        }
    }

    // MARK: - Authorize

    @Test("GET /authorize with JSON accept header returns JSON error")
    func getAuthorizeAPI() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=0"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.add(name: "Accept", value: "application/json")
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .badRequest)
                    #expect(res.headers.contentType == HTTPMediaType.json)
                }
            )
        }
    }

    @Test("GET /authorize with HTML accept header returns HTML error")
    func getAuthorizeWeb() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=0"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                beforeRequest: { @Sendable req async throws in
                    req.headers.add(name: "Accept", value: "text/html")
                },
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .badRequest)
                    #expect(res.headers.contentType == HTTPMediaType.html)
                }
            )
        }
    }

    @Test("GET /authorize with default accept header returns JSON error")
    func getAuthorizeDefault() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                "authorize"
                    + "?response_type=code"
                    + "&client_id=0"
                    + "&redirect_uri=http://localhost/"
                    + "&scope=test"
                    + "&state=123",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .badRequest)
                    #expect(res.headers.contentType == HTTPMediaType.json)
                }
            )
        }
    }
}
