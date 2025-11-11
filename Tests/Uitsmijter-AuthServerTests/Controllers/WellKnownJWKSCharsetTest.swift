import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

// Tests use unique kid values so they don't interfere with each other
@Suite("JWKS Endpoint charset Tests", .serialized)

struct WellKnownJWKSCharsetTest {
    let decoder = JSONDecoder()

    @Test("JWKS endpoint charset is UTF-8", .disabled("Investigating hang issue"))
    func jwksEndpointCharsetIsUTF8() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    let contentType = res.headers.first(name: .contentType)
                    #expect(contentType?.contains("charset=utf-8") == true)
                }
            )
        }
    }
    
    @Test("JWKS endpoint body is valid UTF-8")
    func jwksEndpointBodyIsValidUTF8() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(
                .GET,
                ".well-known/jwks.json",
                afterResponse: { @Sendable res async throws in
                    #expect(res.status == .ok)

                    // Body should decode as UTF-8 string
                    let bodyString = res.body.string
                    #expect(!bodyString.isEmpty)

                    // Should be valid JSON
                    guard let data = bodyString.data(using: .utf8) else {
                        Issue.record("Failed to encode body as UTF-8")
                        return
                    }

                    let json = try? JSONSerialization.jsonObject(with: data)
                    #expect(json != nil)
                }
            )
        }
    }

}
