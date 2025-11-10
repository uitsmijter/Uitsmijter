import Foundation
@testable import Uitsmijter_AuthServer
import Testing

/// Tests for Prometheus concurrent access and edge cases
@Suite("Prometheus Advanced Tests")
struct PrometheusAdvancedTest {

    // MARK: - Concurrent Access Tests

    @Test("Prometheus singleton is thread-safe")
    func prometheusSingletonThreadSafe() async {
        // Access from multiple tasks concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let prometheus = Prometheus.main
                    _ = prometheus.getClient()
                    // Successfully got client
                }
            }
        }
        // All tasks completed without crashing
    }

    @Test("Metrics can be updated concurrently")
    func metricsConcurrentUpdates() async {
        _ = Prometheus.main

        // Verify metrics are initialized
        #expect(Prometheus.main.loginAttempts != nil)
        #expect(Prometheus.main.loginSuccess != nil)
        #expect(Prometheus.main.oauthSuccess != nil)
        #expect(Prometheus.main.authorizeAttempts != nil)
        #expect(Prometheus.main.interceptorSuccess != nil)
        #expect(Prometheus.main.countTenants != nil)

        await withTaskGroup(of: Void.self) { group in
            // Multiple tasks updating different metrics
            for _ in 0..<5 {
                group.addTask {
                    Prometheus.main.loginAttempts?.observe(1)
                    Prometheus.main.loginSuccess?.inc()
                }

                group.addTask {
                    Prometheus.main.oauthSuccess?.inc()
                    Prometheus.main.authorizeAttempts?.observe(1)
                }

                group.addTask {
                    Prometheus.main.interceptorSuccess?.inc()
                    Prometheus.main.countTenants?.inc()
                }
            }
        }
    }

    // MARK: - Edge Cases

    @Test("Metrics can handle zero values")
    func metricsHandleZeroValues() {
        _ = Prometheus.main

        #expect(Prometheus.main.loginAttempts != nil)
        Prometheus.main.loginAttempts?.observe(0)

        #expect(Prometheus.main.authorizeAttempts != nil)
        Prometheus.main.authorizeAttempts?.observe(0)

        #expect(Prometheus.main.tokensStored != nil)
        Prometheus.main.tokensStored?.observe(0)

        #expect(Prometheus.main.countTenants != nil)
        Prometheus.main.countTenants?.set(0)

        #expect(Prometheus.main.countClients != nil)
        Prometheus.main.countClients?.set(0)
    }

    @Test("Metrics can handle large values")
    func metricsHandleLargeValues() {
        _ = Prometheus.main

        #expect(Prometheus.main.loginAttempts != nil)
        Prometheus.main.loginAttempts?.observe(1_000_000)

        #expect(Prometheus.main.authorizeAttempts != nil)
        Prometheus.main.authorizeAttempts?.observe(1_000_000)

        #expect(Prometheus.main.tokensStored != nil)
        Prometheus.main.tokensStored?.observe(1_000_000)

        #expect(Prometheus.main.loginSuccess != nil)
        Prometheus.main.loginSuccess?.inc(1_000_000)

        #expect(Prometheus.main.oauthSuccess != nil)
        Prometheus.main.oauthSuccess?.inc(1_000_000)

        #expect(Prometheus.main.countTenants != nil)
        Prometheus.main.countTenants?.set(10_000)

        #expect(Prometheus.main.countClients != nil)
        Prometheus.main.countClients?.set(100_000)
    }

    @Test("Counters can be incremented by custom amounts")
    func countersCustomIncrements() {
        _ = Prometheus.main

        #expect(Prometheus.main.loginSuccess != nil)
        Prometheus.main.loginSuccess?.inc(1)
        Prometheus.main.loginSuccess?.inc(5)
        Prometheus.main.loginSuccess?.inc(10)
        Prometheus.main.loginSuccess?.inc(100)

        #expect(Prometheus.main.oauthSuccess != nil)
        Prometheus.main.oauthSuccess?.inc(25)

        #expect(Prometheus.main.interceptorSuccess != nil)
        Prometheus.main.interceptorSuccess?.inc(50)
    }

    @Test("Gauges can be decremented by custom amounts")
    func gaugesCustomDecrements() {
        _ = Prometheus.main

        #expect(Prometheus.main.countTenants != nil)
        Prometheus.main.countTenants?.set(100)
        Prometheus.main.countTenants?.dec(1)
        Prometheus.main.countTenants?.dec(5)
        Prometheus.main.countTenants?.dec(10)

        #expect(Prometheus.main.countClients != nil)
        Prometheus.main.countClients?.set(500)
        Prometheus.main.countClients?.dec(25)
        Prometheus.main.countClients?.dec(50)
    }
}
