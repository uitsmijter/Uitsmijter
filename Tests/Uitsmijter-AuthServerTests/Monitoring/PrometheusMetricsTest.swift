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
        #expect(metricsLoginAttempts != nil)
        metricsLoginAttempts?.observe(0)
        metricsLoginAttempts?.observe(1)
        metricsLoginAttempts?.observe(100)
        metricsLoginAttempts?.observe(1000)

        #expect(metricsAuthorizeAttempts != nil)
        metricsAuthorizeAttempts?.observe(0)
        metricsAuthorizeAttempts?.observe(50)

        #expect(metricsTokensStored != nil)
        metricsTokensStored?.observe(0)
        metricsTokensStored?.observe(500)
    }

    // MARK: - Counter Tests

    @Test("Counter metrics can be incremented")
    func counterMetricsIncrement() {
        _ = Prometheus.main

        // Test counters
        #expect(metricsLoginSuccess != nil)
        metricsLoginSuccess?.inc()
        metricsLoginSuccess?.inc(5)

        #expect(metricsLoginFailure != nil)
        metricsLoginFailure?.inc()
        metricsLoginFailure?.inc(10)

        #expect(metricsLogout != nil)
        metricsLogout?.inc()
        metricsLogout?.inc(3)

        #expect(metricsInterceptorSuccess != nil)
        metricsInterceptorSuccess?.inc()

        #expect(metricsInterceptorFailure != nil)
        metricsInterceptorFailure?.inc()

        #expect(metricsOAuthSuccess != nil)
        metricsOAuthSuccess?.inc()

        #expect(metricsOAuthFailure != nil)
        metricsOAuthFailure?.inc()
    }

    // MARK: - Gauge Tests

    @Test("Gauge metrics can be set to specific values")
    func gaugeMetricsSetValue() {
        _ = Prometheus.main

        #expect(metricsCountTenants != nil)
        metricsCountTenants?.set(0)
        metricsCountTenants?.set(1)
        metricsCountTenants?.set(100)

        #expect(metricsCountClients != nil)
        metricsCountClients?.set(0)
        metricsCountClients?.set(50)
        metricsCountClients?.set(1000)
    }

    // MARK: - Practical Usage Tests

    @Test("Simulate login flow with metrics")
    func simulateLoginFlow() {
        _ = Prometheus.main

        // Simulate a login attempt
        #expect(metricsLoginAttempts != nil)
        metricsLoginAttempts?.observe(1)

        // Simulate success
        #expect(metricsLoginSuccess != nil)
        metricsLoginSuccess?.inc()

        // Simulate another attempt that fails
        metricsLoginAttempts?.observe(1)
        #expect(metricsLoginFailure != nil)
        metricsLoginFailure?.inc()

        // Simulate logout
        #expect(metricsLogout != nil)
        metricsLogout?.inc()
    }

    @Test("Simulate OAuth flow with metrics")
    func simulateOAuthFlow() {
        _ = Prometheus.main

        // Simulate authorization attempts
        #expect(metricsAuthorizeAttempts != nil)
        metricsAuthorizeAttempts?.observe(1)

        // Simulate successful OAuth flow
        #expect(metricsOAuthSuccess != nil)
        metricsOAuthSuccess?.inc()

        // Simulate failed OAuth flow
        metricsAuthorizeAttempts?.observe(1)
        #expect(metricsOAuthFailure != nil)
        metricsOAuthFailure?.inc()
    }

    @Test("Simulate interceptor flow with metrics")
    func simulateInterceptorFlow() {
        _ = Prometheus.main

        // Simulate successful interceptor checks
        #expect(metricsInterceptorSuccess != nil)
        metricsInterceptorSuccess?.inc()
        metricsInterceptorSuccess?.inc()
        metricsInterceptorSuccess?.inc()

        // Simulate failed interceptor check
        #expect(metricsInterceptorFailure != nil)
        metricsInterceptorFailure?.inc()
    }

    @Test("Simulate entity management with metrics")
    func simulateEntityManagement() {
        _ = Prometheus.main

        // Start with no entities
        #expect(metricsCountTenants != nil)
        metricsCountTenants?.set(0)

        #expect(metricsCountClients != nil)
        metricsCountClients?.set(0)

        // Add tenants
        metricsCountTenants?.inc()
        metricsCountTenants?.inc()

        // Add clients
        metricsCountClients?.inc(5)

        // Remove a tenant
        metricsCountTenants?.dec()

        // Remove clients
        metricsCountClients?.dec(2)
    }

    @Test("Simulate token storage tracking")
    func simulateTokenStorage() {
        _ = Prometheus.main

        // Track token counts over time
        #expect(metricsTokensStored != nil)
        metricsTokensStored?.observe(0)
        metricsTokensStored?.observe(10)
        metricsTokensStored?.observe(25)
        metricsTokensStored?.observe(50)
        metricsTokensStored?.observe(45) // Some tokens expired
        metricsTokensStored?.observe(40)
    }
}
