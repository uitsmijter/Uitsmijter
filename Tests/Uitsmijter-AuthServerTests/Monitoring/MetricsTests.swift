import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Metrics Endpoint Tests")
struct MetricsTests {

    @Test("GET /metrics returns prometheus metrics")
    func getMetrics() async throws {
        try await withApp(configure: configure) { app in

            _ = try await app.testing().test(.GET, "health")

            try await app.testing().test(.GET, "metrics", beforeRequest: { @Sendable req async throws in
                req.headers.add(
                    name: "Accept",
                    value: "application/openmetrics-text; version=0.0.1,text/plain;version=0.0.4;q=0.5,*/*;q=0.1"
                )
            }, afterResponse: { @Sendable res async throws in
                #expect(res.status == .ok)

                #expect(res.body.string.contains("http_requests_total"))

                #expect(res.body.string.contains("uitsmijter_tenants_count"))
                #expect(res.body.string.contains("uitsmijter_clients_count"))

                #expect(res.body.string.contains("uitsmijter_login_attempts"))
                #expect(res.body.string.contains("uitsmijter_login_success"))
                #expect(res.body.string.contains("uitsmijter_login_failure"))

                #expect(res.body.string.contains("uitsmijter_logout"))
                #expect(res.body.string.contains("uitsmijter_interceptor_success"))
                #expect(res.body.string.contains("uitsmijter_interceptor_failure"))

                #expect(res.body.string.contains("uitsmijter_authorize_attempts"))
                #expect(res.body.string.contains("uitsmijter_oauth_success"))
                #expect(res.body.string.contains("uitsmijter_oauth_failure"))

                #expect(res.body.string.contains("uitsmijter_token_stored"))
            })
        }
    }
}
