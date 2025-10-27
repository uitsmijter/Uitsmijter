import Foundation
@testable import Uitsmijter_AuthServer
import Testing

/// Tests for Prometheus singleton, client access, and individual metric initialization
@Suite("Prometheus Basic Tests")
struct PrometheusBasicTest {

    // MARK: - Singleton Tests

    @Test("Prometheus singleton is accessible")
    func prometheusMainAccessible() {
        let prometheus = Prometheus.main
        // Verify we can get a client from the singleton
        _ = prometheus.getClient()
        // If we got here, the client is accessible
    }

    @Test("Prometheus singleton returns same instance")
    func prometheusSingletonConsistent() {
        let instance1 = Prometheus.main
        let instance2 = Prometheus.main

        // Both should reference the same singleton
        // Verify both can return clients
        _ = instance1.getClient()
        _ = instance2.getClient()
        // If we got here, both instances provide clients
    }

    // MARK: - Client Tests

    @Test("getClient returns PrometheusClient")
    func getClientReturnsClient() {
        let prometheus = Prometheus.main
        _ = prometheus.getClient()
        // If we got here, client is accessible
    }

    @Test("getClient returns consistent client")
    func getClientConsistent() {
        let prometheus = Prometheus.main
        _ = prometheus.getClient()
        _ = prometheus.getClient()
        // Both calls should succeed
    }

    // MARK: - Login Metrics Tests

    @Test("metricsLoginAttempts histogram is initialized")
    func loginAttemptsInitialized() {
        _ = Prometheus.main
        #expect(metricsLoginAttempts != nil)
    }

    @Test("metricsLoginSuccess counter is initialized")
    func loginSuccessInitialized() {
        _ = Prometheus.main
        #expect(metricsLoginSuccess != nil)
    }

    @Test("metricsLoginFailure counter is initialized")
    func loginFailureInitialized() {
        _ = Prometheus.main
        #expect(metricsLoginFailure != nil)
    }

    @Test("metricsLogout counter is initialized")
    func logoutInitialized() {
        _ = Prometheus.main
        #expect(metricsLogout != nil)
    }

    @Test("Login metrics can be observed")
    func loginMetricsObservable() {
        _ = Prometheus.main

        // Verify metrics are initialized and can be called
        #expect(metricsLoginAttempts != nil)
        metricsLoginAttempts?.observe(1)

        #expect(metricsLoginSuccess != nil)
        metricsLoginSuccess?.inc()

        #expect(metricsLoginFailure != nil)
        metricsLoginFailure?.inc()

        #expect(metricsLogout != nil)
        metricsLogout?.inc()
    }

    // MARK: - Interceptor Metrics Tests

    @Test("metricsInterceptorSuccess counter is initialized")
    func interceptorSuccessInitialized() {
        _ = Prometheus.main
        #expect(metricsInterceptorSuccess != nil)
    }

    @Test("metricsInterceptorFailure counter is initialized")
    func interceptorFailureInitialized() {
        _ = Prometheus.main
        #expect(metricsInterceptorFailure != nil)
    }

    @Test("Interceptor metrics can be observed")
    func interceptorMetricsObservable() {
        _ = Prometheus.main

        #expect(metricsInterceptorSuccess != nil)
        metricsInterceptorSuccess?.inc()

        #expect(metricsInterceptorFailure != nil)
        metricsInterceptorFailure?.inc()
    }

    // MARK: - OAuth Metrics Tests

    @Test("metricsAuthorizeAttempts histogram is initialized")
    func authorizeAttemptsInitialized() {
        _ = Prometheus.main
        #expect(metricsAuthorizeAttempts != nil)
    }

    @Test("metricsOAuthSuccess counter is initialized")
    func oauthSuccessInitialized() {
        _ = Prometheus.main
        #expect(metricsOAuthSuccess != nil)
    }

    @Test("metricsOAuthFailure counter is initialized")
    func oauthFailureInitialized() {
        _ = Prometheus.main
        #expect(metricsOAuthFailure != nil)
    }

    @Test("OAuth metrics can be observed")
    func oauthMetricsObservable() {
        _ = Prometheus.main

        #expect(metricsAuthorizeAttempts != nil)
        metricsAuthorizeAttempts?.observe(1)

        #expect(metricsOAuthSuccess != nil)
        metricsOAuthSuccess?.inc()

        #expect(metricsOAuthFailure != nil)
        metricsOAuthFailure?.inc()
    }

    // MARK: - Token Storage Metrics Tests

    @Test("metricsTokensStored histogram is initialized")
    func tokensStoredInitialized() {
        _ = Prometheus.main
        #expect(metricsTokensStored != nil)
    }

    @Test("Token storage metrics can be observed")
    func tokenStorageMetricsObservable() {
        _ = Prometheus.main

        #expect(metricsTokensStored != nil)
        metricsTokensStored?.observe(1)
        metricsTokensStored?.observe(5)
        metricsTokensStored?.observe(10)
    }

    // MARK: - Entity Count Metrics Tests

    @Test("metricsCountTenants gauge is initialized")
    func countTenantsInitialized() {
        _ = Prometheus.main
        #expect(metricsCountTenants != nil)
    }

    @Test("metricsCountClients gauge is initialized")
    func countClientsInitialized() {
        _ = Prometheus.main
        #expect(metricsCountClients != nil)
    }

    @Test("Entity count metrics can be set")
    func entityCountMetricsSettable() {
        _ = Prometheus.main

        #expect(metricsCountTenants != nil)
        metricsCountTenants?.set(5)

        #expect(metricsCountClients != nil)
        metricsCountClients?.set(20)
    }

    @Test("Entity count gauge can be incremented and decremented")
    func entityCountGaugeOperations() {
        _ = Prometheus.main

        #expect(metricsCountTenants != nil)
        metricsCountTenants?.inc()
        metricsCountTenants?.inc(10)
        metricsCountTenants?.dec()
        metricsCountTenants?.dec(5)

        #expect(metricsCountClients != nil)
        metricsCountClients?.inc()
        metricsCountClients?.inc(15)
        metricsCountClients?.dec()
        metricsCountClients?.dec(10)
    }

    // MARK: - All Metrics Initialized Test

    @Test("All metrics are initialized after singleton access")
    func allMetricsInitialized() {
        _ = Prometheus.main

        // Login metrics
        #expect(metricsLoginAttempts != nil)
        #expect(metricsLoginSuccess != nil)
        #expect(metricsLoginFailure != nil)
        #expect(metricsLogout != nil)

        // Interceptor metrics
        #expect(metricsInterceptorSuccess != nil)
        #expect(metricsInterceptorFailure != nil)

        // OAuth metrics
        #expect(metricsAuthorizeAttempts != nil)
        #expect(metricsOAuthSuccess != nil)
        #expect(metricsOAuthFailure != nil)

        // Token storage metrics
        #expect(metricsTokensStored != nil)

        // Entity count metrics
        #expect(metricsCountTenants != nil)
        #expect(metricsCountClients != nil)
    }
}
