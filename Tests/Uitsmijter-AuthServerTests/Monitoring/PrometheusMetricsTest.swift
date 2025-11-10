import Foundation
@testable import Uitsmijter_AuthServer
import Testing

/// Tests for Prometheus histogram, counter, and gauge metric types plus practical usage scenarios
@Suite("Prometheus Metrics Tests")
struct PrometheusMetricsTest {

    // MARK: - Histogram Tests

    @Test("Histogram metrics accept various observation values")
    func histogramAcceptsVariousValues() {
        _ = Prometheus.main

        // Test with different values
        #expect(Prometheus.main.loginAttempts != nil)
        Prometheus.main.loginAttempts?.observe(0)
        Prometheus.main.loginAttempts?.observe(1)
        Prometheus.main.loginAttempts?.observe(100)
        Prometheus.main.loginAttempts?.observe(1000)

        #expect(Prometheus.main.authorizeAttempts != nil)
        Prometheus.main.authorizeAttempts?.observe(0)
        Prometheus.main.authorizeAttempts?.observe(50)

        #expect(Prometheus.main.tokensStored != nil)
        Prometheus.main.tokensStored?.observe(0)
        Prometheus.main.tokensStored?.observe(500)
    }

    // MARK: - Counter Tests

    @Test("Counter metrics can be incremented")
    func counterMetricsIncrement() {
        _ = Prometheus.main

        // Test counters
        #expect(Prometheus.main.loginSuccess != nil)
        Prometheus.main.loginSuccess?.inc()
        Prometheus.main.loginSuccess?.inc(5)

        #expect(Prometheus.main.loginFailure != nil)
        Prometheus.main.loginFailure?.inc()
        Prometheus.main.loginFailure?.inc(10)

        #expect(Prometheus.main.logout != nil)
        Prometheus.main.logout?.inc()
        Prometheus.main.logout?.inc(3)

        #expect(Prometheus.main.interceptorSuccess != nil)
        Prometheus.main.interceptorSuccess?.inc()

        #expect(Prometheus.main.interceptorFailure != nil)
        Prometheus.main.interceptorFailure?.inc()

        #expect(Prometheus.main.oauthSuccess != nil)
        Prometheus.main.oauthSuccess?.inc()

        #expect(Prometheus.main.oauthFailure != nil)
        Prometheus.main.oauthFailure?.inc()
    }

    // MARK: - Gauge Tests

    @Test("Gauge metrics can be set to specific values")
    func gaugeMetricsSetValue() {
        _ = Prometheus.main

        #expect(Prometheus.main.countTenants != nil)
        Prometheus.main.countTenants?.set(0)
        Prometheus.main.countTenants?.set(1)
        Prometheus.main.countTenants?.set(100)

        #expect(Prometheus.main.countClients != nil)
        Prometheus.main.countClients?.set(0)
        Prometheus.main.countClients?.set(50)
        Prometheus.main.countClients?.set(1000)
    }

    // MARK: - Practical Usage Tests

    @Test("Simulate login flow with metrics")
    func simulateLoginFlow() {
        _ = Prometheus.main

        // Simulate a login attempt
        #expect(Prometheus.main.loginAttempts != nil)
        Prometheus.main.loginAttempts?.observe(1)

        // Simulate success
        #expect(Prometheus.main.loginSuccess != nil)
        Prometheus.main.loginSuccess?.inc()

        // Simulate another attempt that fails
        Prometheus.main.loginAttempts?.observe(1)
        #expect(Prometheus.main.loginFailure != nil)
        Prometheus.main.loginFailure?.inc()

        // Simulate logout
        #expect(Prometheus.main.logout != nil)
        Prometheus.main.logout?.inc()
    }

    @Test("Simulate OAuth flow with metrics")
    func simulateOAuthFlow() {
        _ = Prometheus.main

        // Simulate authorization attempts
        #expect(Prometheus.main.authorizeAttempts != nil)
        Prometheus.main.authorizeAttempts?.observe(1)

        // Simulate successful OAuth flow
        #expect(Prometheus.main.oauthSuccess != nil)
        Prometheus.main.oauthSuccess?.inc()

        // Simulate failed OAuth flow
        Prometheus.main.authorizeAttempts?.observe(1)
        #expect(Prometheus.main.oauthFailure != nil)
        Prometheus.main.oauthFailure?.inc()
    }

    @Test("Simulate interceptor flow with metrics")
    func simulateInterceptorFlow() {
        _ = Prometheus.main

        // Simulate successful interceptor checks
        #expect(Prometheus.main.interceptorSuccess != nil)
        Prometheus.main.interceptorSuccess?.inc()
        Prometheus.main.interceptorSuccess?.inc()
        Prometheus.main.interceptorSuccess?.inc()

        // Simulate failed interceptor check
        #expect(Prometheus.main.interceptorFailure != nil)
        Prometheus.main.interceptorFailure?.inc()
    }

    @Test("Simulate entity management with metrics")
    func simulateEntityManagement() {
        _ = Prometheus.main

        // Start with no entities
        #expect(Prometheus.main.countTenants != nil)
        Prometheus.main.countTenants?.set(0)

        #expect(Prometheus.main.countClients != nil)
        Prometheus.main.countClients?.set(0)

        // Add tenants
        Prometheus.main.countTenants?.inc()
        Prometheus.main.countTenants?.inc()

        // Add clients
        Prometheus.main.countClients?.inc(5)

        // Remove a tenant
        Prometheus.main.countTenants?.dec()

        // Remove clients
        Prometheus.main.countClients?.dec(2)
    }

    @Test("Simulate token storage tracking")
    func simulateTokenStorage() {
        _ = Prometheus.main

        // Track token counts over time
        #expect(Prometheus.main.tokensStored != nil)
        Prometheus.main.tokensStored?.observe(0)
        Prometheus.main.tokensStored?.observe(10)
        Prometheus.main.tokensStored?.observe(25)
        Prometheus.main.tokensStored?.observe(50)
        Prometheus.main.tokensStored?.observe(45) // Some tokens expired
        Prometheus.main.tokensStored?.observe(40)
    }
}
