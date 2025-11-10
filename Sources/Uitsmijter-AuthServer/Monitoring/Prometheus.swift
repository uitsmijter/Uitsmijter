import Foundation
@preconcurrency import Prometheus
import Metrics

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
/// Prometheus.main.loginAttempts?.observe(1)
/// Prometheus.main.loginSuccess?.inc()
///
/// // Get the client for custom metrics
/// let client = prometheus.getClient()
/// ```
///
/// - Complexity: Singleton pattern ensures single PrometheusClient instance
///
struct Prometheus: Sendable {
    /// Singleton reference
    static let main: Prometheus = Prometheus()

    /// The static prometheus client
    private static let prometheusClient = PrometheusClient()

    /// The application name prefix for metrics
    private static let metricsPrefix = "uitsmijter"

    /// How many attempts to login
    let loginAttempts: PromHistogram<Int>?
    /// How many logins succeeded over time
    let loginSuccess: PromCounter<Int>?
    /// How many logins failed over time
    let loginFailure: PromCounter<Int>?
    /// How many logouts happens over time
    let logout: PromCounter<Int>?

    /// How many request pass the interceptor flow successfully over time
    let interceptorSuccess: PromCounter<Int>?
    /// How many request fails the interceptor flow over time
    let interceptorFailure: PromCounter<Int>?

    /// How many attempts to /authorize
    let authorizeAttempts: PromHistogram<Int>?
    /// How many OAuth flows succeeded over time
    let oauthSuccess: PromCounter<Int>?
    /// How many OAuth flows failed over time
    let oauthFailure: PromCounter<Int>?

    /// How many token revocations succeeded over time
    let revokeSuccess: PromCounter<Int>?
    /// How many token revocations failed over time
    let revokeFailure: PromCounter<Int>?

    /// How may tokens are in the store
    let tokensStored: PromHistogram<Int>?

    /// Currently known tenants
    let countTenants: PromGauge<Int>?
    /// Currently known clients
    let countClients: PromGauge<Int>?

    /// Private init to initialize the singleton once
    private init() {
        MetricsSystem.bootstrap(PrometheusMetricsFactory(client: Prometheus.prometheusClient))

        let client = Prometheus.prometheusClient

        self.loginAttempts = client.createHistogram(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_login_attempts",
            helpText: "Histogram of the number of total login attempts regardless of result (success/failure)."
        )
        self.loginSuccess = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_login_success",
            helpText: "Counter of successful logins."
        )
        self.loginFailure = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_login_failure",
            helpText: "Counter of failed logins (wrong credentials or technical failure)."
        )
        self.logout = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_logout",
            helpText: "Counter of successful logout actions."
        )

        self.interceptorSuccess = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_interceptor_success",
            helpText: "Counter of authorized accesses to pages using the interceptor middleware."
        )
        self.interceptorFailure = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_interceptor_failure",
            helpText: "Counter of failures trying to access pages using the interceptor middleware."
        )

        self.authorizeAttempts = client.createHistogram(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_authorize_attempts",
            helpText: "Histogramm of OAuth authorization attempts regardless of result (success/failure)."
        )
        self.oauthSuccess = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_oauth_success",
            helpText: "Counter of successful OAuth token authorizations (all grant types)."
        )
        self.oauthFailure = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_oauth_failure",
            helpText: "Counter of failed OAuth token authorizations (all grant types)."
        )

        self.revokeSuccess = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_revoke_success",
            helpText: "Counter of successful token revocations."
        )
        self.revokeFailure = client.createCounter(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_revoke_failure",
            helpText: "Counter of failed token revocations (authentication failures)."
        )

        self.tokensStored = client.createHistogram(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_token_stored",
            helpText: "Histogram of valid refresh tokens over time."
        )

        self.countTenants = client.createGauge(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_tenants_count",
            helpText: "Current number of managed tenants."
        )
        self.countClients = client.createGauge(
            forType: Int.self,
            named: "\(Prometheus.metricsPrefix)_clients_count",
            helpText: "Current number of managed clients for all tenants."
        )
    }

    /// Return the global prometheus client
    ///
    /// - Returns: The prometheus client
    ///
    func getClient() -> PrometheusClient {
        Prometheus.prometheusClient
    }

}
