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
        #expect(metricsLoginAttempts != nil)
        #expect(metricsLoginSuccess != nil)
        #expect(metricsOAuthSuccess != nil)
        #expect(metricsAuthorizeAttempts != nil)
        #expect(metricsInterceptorSuccess != nil)
        #expect(metricsCountTenants != nil)

        await withTaskGroup(of: Void.self) { group in
            // Multiple tasks updating different metrics
            for _ in 0..<5 {
                group.addTask {
                    metricsLoginAttempts?.observe(1)
                    metricsLoginSuccess?.inc()
                }

                group.addTask {
                    metricsOAuthSuccess?.inc()
                    metricsAuthorizeAttempts?.observe(1)
                }

                group.addTask {
                    metricsInterceptorSuccess?.inc()
                    metricsCountTenants?.inc()
                }
            }
        }
    }

    // MARK: - Edge Cases

    @Test("Metrics can handle zero values")
    func metricsHandleZeroValues() {
        _ = Prometheus.main

        #expect(metricsLoginAttempts != nil)
        metricsLoginAttempts?.observe(0)

        #expect(metricsAuthorizeAttempts != nil)
        metricsAuthorizeAttempts?.observe(0)

        #expect(metricsTokensStored != nil)
        metricsTokensStored?.observe(0)

        #expect(metricsCountTenants != nil)
        metricsCountTenants?.set(0)

        #expect(metricsCountClients != nil)
        metricsCountClients?.set(0)
    }

    @Test("Metrics can handle large values")
    func metricsHandleLargeValues() {
        _ = Prometheus.main

        #expect(metricsLoginAttempts != nil)
        metricsLoginAttempts?.observe(1_000_000)

        #expect(metricsAuthorizeAttempts != nil)
        metricsAuthorizeAttempts?.observe(1_000_000)

        #expect(metricsTokensStored != nil)
        metricsTokensStored?.observe(1_000_000)

        #expect(metricsLoginSuccess != nil)
        metricsLoginSuccess?.inc(1_000_000)

        #expect(metricsOAuthSuccess != nil)
        metricsOAuthSuccess?.inc(1_000_000)

        #expect(metricsCountTenants != nil)
        metricsCountTenants?.set(10_000)

        #expect(metricsCountClients != nil)
        metricsCountClients?.set(100_000)
    }

    @Test("Counters can be incremented by custom amounts")
    func countersCustomIncrements() {
        _ = Prometheus.main

        #expect(metricsLoginSuccess != nil)
        metricsLoginSuccess?.inc(1)
        metricsLoginSuccess?.inc(5)
        metricsLoginSuccess?.inc(10)
        metricsLoginSuccess?.inc(100)

        #expect(metricsOAuthSuccess != nil)
        metricsOAuthSuccess?.inc(25)

        #expect(metricsInterceptorSuccess != nil)
        metricsInterceptorSuccess?.inc(50)
    }

    @Test("Gauges can be decremented by custom amounts")
    func gaugesCustomDecrements() {
        _ = Prometheus.main

        #expect(metricsCountTenants != nil)
        metricsCountTenants?.set(100)
        metricsCountTenants?.dec(1)
        metricsCountTenants?.dec(5)
        metricsCountTenants?.dec(10)

        #expect(metricsCountClients != nil)
        metricsCountClients?.set(500)
        metricsCountClients?.dec(25)
        metricsCountClients?.dec(50)
    }
}
