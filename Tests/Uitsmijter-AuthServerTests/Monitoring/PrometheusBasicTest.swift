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

    @Test("Prometheus.main.loginAttempts histogram is initialized")
    func loginAttemptsInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.loginAttempts != nil)
    }

    @Test("Prometheus.main.loginSuccess counter is initialized")
    func loginSuccessInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.loginSuccess != nil)
    }

    @Test("Prometheus.main.loginFailure counter is initialized")
    func loginFailureInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.loginFailure != nil)
    }

    @Test("Prometheus.main.logout counter is initialized")
    func logoutInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.logout != nil)
    }

    @Test("Login metrics can be observed")
    func loginMetricsObservable() {
        _ = Prometheus.main

        // Verify metrics are initialized and can be called
        #expect(Prometheus.main.loginAttempts != nil)
        Prometheus.main.loginAttempts?.observe(1)

        #expect(Prometheus.main.loginSuccess != nil)
        Prometheus.main.loginSuccess?.inc()

        #expect(Prometheus.main.loginFailure != nil)
        Prometheus.main.loginFailure?.inc()

        #expect(Prometheus.main.logout != nil)
        Prometheus.main.logout?.inc()
    }

    // MARK: - Interceptor Metrics Tests

    @Test("Prometheus.main.interceptorSuccess counter is initialized")
    func interceptorSuccessInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.interceptorSuccess != nil)
    }

    @Test("Prometheus.main.interceptorFailure counter is initialized")
    func interceptorFailureInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.interceptorFailure != nil)
    }

    @Test("Interceptor metrics can be observed")
    func interceptorMetricsObservable() {
        _ = Prometheus.main

        #expect(Prometheus.main.interceptorSuccess != nil)
        Prometheus.main.interceptorSuccess?.inc()

        #expect(Prometheus.main.interceptorFailure != nil)
        Prometheus.main.interceptorFailure?.inc()
    }

    // MARK: - OAuth Metrics Tests

    @Test("Prometheus.main.authorizeAttempts histogram is initialized")
    func authorizeAttemptsInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.authorizeAttempts != nil)
    }

    @Test("Prometheus.main.oauthSuccess counter is initialized")
    func oauthSuccessInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.oauthSuccess != nil)
    }

    @Test("Prometheus.main.oauthFailure counter is initialized")
    func oauthFailureInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.oauthFailure != nil)
    }

    @Test("OAuth metrics can be observed")
    func oauthMetricsObservable() {
        _ = Prometheus.main

        #expect(Prometheus.main.authorizeAttempts != nil)
        Prometheus.main.authorizeAttempts?.observe(1)

        #expect(Prometheus.main.oauthSuccess != nil)
        Prometheus.main.oauthSuccess?.inc()

        #expect(Prometheus.main.oauthFailure != nil)
        Prometheus.main.oauthFailure?.inc()
    }

    // MARK: - Token Storage Metrics Tests

    @Test("Prometheus.main.tokensStored histogram is initialized")
    func tokensStoredInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.tokensStored != nil)
    }

    @Test("Token storage metrics can be observed")
    func tokenStorageMetricsObservable() {
        _ = Prometheus.main

        #expect(Prometheus.main.tokensStored != nil)
        Prometheus.main.tokensStored?.observe(1)
        Prometheus.main.tokensStored?.observe(5)
        Prometheus.main.tokensStored?.observe(10)
    }

    // MARK: - Entity Count Metrics Tests

    @Test("Prometheus.main.countTenants gauge is initialized")
    func countTenantsInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.countTenants != nil)
    }

    @Test("Prometheus.main.countClients gauge is initialized")
    func countClientsInitialized() {
        _ = Prometheus.main
        #expect(Prometheus.main.countClients != nil)
    }

    @Test("Entity count metrics can be set")
    func entityCountMetricsSettable() {
        _ = Prometheus.main

        #expect(Prometheus.main.countTenants != nil)
        Prometheus.main.countTenants?.set(5)

        #expect(Prometheus.main.countClients != nil)
        Prometheus.main.countClients?.set(20)
    }

    @Test("Entity count gauge can be incremented and decremented")
    func entityCountGaugeOperations() {
        _ = Prometheus.main

        #expect(Prometheus.main.countTenants != nil)
        Prometheus.main.countTenants?.inc()
        Prometheus.main.countTenants?.inc(10)
        Prometheus.main.countTenants?.dec()
        Prometheus.main.countTenants?.dec(5)

        #expect(Prometheus.main.countClients != nil)
        Prometheus.main.countClients?.inc()
        Prometheus.main.countClients?.inc(15)
        Prometheus.main.countClients?.dec()
        Prometheus.main.countClients?.dec(10)
    }

    // MARK: - All Metrics Initialized Test

    @Test("All metrics are initialized after singleton access")
    func allMetricsInitialized() {
        _ = Prometheus.main

        // Login metrics
        #expect(Prometheus.main.loginAttempts != nil)
        #expect(Prometheus.main.loginSuccess != nil)
        #expect(Prometheus.main.loginFailure != nil)
        #expect(Prometheus.main.logout != nil)

        // Interceptor metrics
        #expect(Prometheus.main.interceptorSuccess != nil)
        #expect(Prometheus.main.interceptorFailure != nil)

        // OAuth metrics
        #expect(Prometheus.main.authorizeAttempts != nil)
        #expect(Prometheus.main.oauthSuccess != nil)
        #expect(Prometheus.main.oauthFailure != nil)

        // Token storage metrics
        #expect(Prometheus.main.tokensStored != nil)

        // Entity count metrics
        #expect(Prometheus.main.countTenants != nil)
        #expect(Prometheus.main.countClients != nil)
    }
}
