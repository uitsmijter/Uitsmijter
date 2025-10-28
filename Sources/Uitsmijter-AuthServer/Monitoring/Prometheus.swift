import Foundation
@preconcurrency import Prometheus
import Metrics

/// How many attempts to login
nonisolated(unsafe) var metricsLoginAttempts: PromHistogram<Int>?
/// How many logins succeeded over time
nonisolated(unsafe) var metricsLoginSuccess: PromCounter<Int>?
/// How many logins failed over time
nonisolated(unsafe) var metricsLoginFailure: PromCounter<Int>?
/// How many logouts happens over time
nonisolated(unsafe) var metricsLogout: PromCounter<Int>?

/// How many request pass the interceptor flow successfully over time
nonisolated(unsafe) var metricsInterceptorSuccess: PromCounter<Int>?
/// How many request fails the interceptor flow over time
nonisolated(unsafe) var metricsInterceptorFailure: PromCounter<Int>?

/// How many attempts to /authorize
nonisolated(unsafe) var metricsAuthorizeAttempts: PromHistogram<Int>?
/// How many OAuth flows succeeded over time
nonisolated(unsafe) var metricsOAuthSuccess: PromCounter<Int>?
/// How many OAuth flows failed over time
nonisolated(unsafe) var metricsOAuthFailure: PromCounter<Int>?

// How may tokens are in the store
nonisolated(unsafe) var metricsTokensStored: PromHistogram<Int>?

// Currently known tenants
nonisolated(unsafe) var metricsCountTenants: PromGauge<Int>?
// Currently known tenants
nonisolated(unsafe) var metricsCountClients: PromGauge<Int>?

/// Registers a single prometheus client and registers metrics for monitoring
///
/// This struct provides a centralized Prometheus metrics system for the Uitsmijter application.
/// It manages counters, histograms, and gauges for tracking login attempts, OAuth flows,
/// interceptor operations, and entity counts.
///
/// ## Usage
/// ```swift
/// // Initialize the singleton (done automatically on first access)
/// let prometheus = Prometheus.main
///
/// // Access metrics
/// metricsLoginAttempts?.observe(1)
/// metricsLoginSuccess?.inc()
///
/// // Get the client for custom metrics
/// let client = prometheus.getClient()
/// ```
///
/// - Complexity: Singleton pattern ensures single PrometheusClient instance
///
public struct Prometheus: Sendable {
    /// Singleton reference
    public static let main: Prometheus = Prometheus()

    /// The static prometheus client
    private nonisolated(unsafe) static let prometheusClient = PrometheusClient()

    /// The application name prefix for metrics
    private static let metricsPrefix = "uitsmijter"

    /// Private init to initialize the singleton once
    private init() {
        MetricsSystem.bootstrap(PrometheusMetricsFactory(client: Prometheus.prometheusClient))
        configureMetrics()
    }

    /// Return the global prometheus client
    ///
    /// - Returns: The prometheus client
    ///
    public func getClient() -> PrometheusClient {
        Prometheus.prometheusClient
    }

    /// Configure all Prometheus metrics
    ///
    /// Sets up histograms, counters, and gauges for tracking:
    /// - Login/logout operations
    /// - Interceptor middleware operations
    /// - OAuth authorization flows
    /// - Token storage
    /// - Tenant and client counts
    ///
    private func configureMetrics() {
        let client = Prometheus.prometheusClient

        metricsLoginAttempts = client.createHistogram(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_login_attempts",
            helpText: "Histogram of the number of total login attempts regardless of result (success/failure)."
        )
        metricsLoginSuccess = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_login_success",
            helpText: "Counter of successful logins."
        )
        metricsLoginFailure = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_login_failure",
            helpText: "Counter of failed logins (wrong credentials or technical failure)."
        )
        metricsLogout = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_logout",
            helpText: "Counter of successful logout actions."
        )

        metricsInterceptorSuccess = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_interceptor_success",
            helpText: "Counter of authorized accesses to pages using the interceptor middleware."
        )
        metricsInterceptorFailure = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_interceptor_failure",
            helpText: "Counter of failures trying to access pages using the interceptor middleware."
        )

        metricsAuthorizeAttempts = client.createHistogram(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_authorize_attempts",
            helpText: "Histogramm of OAuth authorization attempts regardless of result (success/failure)."
        )
        metricsOAuthSuccess = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_oauth_success",
            helpText: "Counter of successful OAuth token authorizations (all grant types)."
        )
        metricsOAuthFailure = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_oauth_failure",
            helpText: "Counter of failed OAuth token authorizations (all grant types)."
        )

        metricsTokensStored = client.createHistogram(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_token_stored",
            helpText: "Histogram of valid refresh tokens over time."
        )

        metricsCountTenants = client.createGauge(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_tenants_count",
            helpText: "Current number of managed tenants."
        )
        metricsCountClients = client.createGauge(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_clients_count",
            helpText: "Current number of managed clients for all tenants."
        )
    }
}
