import Foundation
import Prometheus
import Metrics

/// How many attempts to login
var metricsLoginAttempts: PromHistogram<Int>?
/// How many logins succeeded over time
var metricsLoginSuccess: PromCounter<Int>?
/// How many logins failed over time
var metricsLoginFailure: PromCounter<Int>?
/// How many logouts happens over time
var metricsLogout: PromCounter<Int>?

/// How many request pass the interceptor flow successfully over time
var metricsInterceptorSuccess: PromCounter<Int>?
/// How many request fails the interceptor flow over time
var metricsInterceptorFailure: PromCounter<Int>?

/// How many attempts to /authorize
var metricsAuthorizeAttempts: PromHistogram<Int>?
/// How many OAuth flows succeeded over time
var metricsOAuthSuccess: PromCounter<Int>?
/// How many OAuth flows failed over time
var metricsOAuthFailure: PromCounter<Int>?

// How may tokens are in the store
var metricsTokensStored: PromHistogram<Int>?

// Currently known tenants
var metricsCountTenants: PromGauge<Int>?
// Currently known tenants
var metricsCountClients: PromGauge<Int>?

/// registers a single prometheus client and register some metrics
/// - Complexity: Singleton
///
struct Prometheus {
    /// Singleton reference
    public static let main: Prometheus = Prometheus()

    /// The static prometheus client
    private static let prometheusClient = PrometheusClient()

    /// Private init to initialize the singleton once
    private init() {
        MetricsSystem.bootstrap(PrometheusMetricsFactory(client: Prometheus.prometheusClient))
        configureMetrics()
    }

    /// Return the global prometheus client
    ///
    /// - Returns: The prometheus client
    ///
    func getClient() -> PrometheusClient {
        Prometheus.prometheusClient
    }

    /// Configure Metrics
    private func configureMetrics() {
        let client = Prometheus.prometheusClient

        metricsLoginAttempts = client.createHistogram(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_login_attempts",
                helpText: "Histogram of the number of total login attempts regardless of result (success/failure)."
        )
        metricsLoginSuccess = client.createCounter(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_login_success",
                helpText: "Counter of successful logins."
        )
        metricsLoginFailure = client.createCounter(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_login_failure",
                helpText: "Counter of failed logins (wrong credentials or technical failure)."
        )
        metricsLogout = client.createCounter(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_logout",
                helpText: "Counter of successful logout actions."
        )

        metricsInterceptorSuccess = client.createCounter(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_interceptor_success",
                helpText: "Counter of authorized accesses to pages using the interceptor middleware."
        )
        metricsInterceptorFailure = client.createCounter(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_interceptor_failure",
                helpText: "Counter of failures trying to access pages using the interceptor middleware."
        )

        metricsAuthorizeAttempts = client.createHistogram(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_authorize_attempts",
                helpText: "Histogramm of OAuth authorization attempts regardless of result (success/failure)."
        )
        metricsOAuthSuccess = client.createCounter(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_oauth_success",
                helpText: "Counter of successful OAuth token authorizations (all grant types)."
        )
        metricsOAuthFailure = client.createCounter(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_oauth_failure",
                helpText: "Counter of failed OAuth token authorizations (all grant types)."
        )

        metricsTokensStored = client.createHistogram(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_token_stored",
                helpText: "Histogram of valid refresh tokens over time."
        )

        metricsCountTenants = client.createGauge(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_tenants_count",
                helpText: "Current number of managed tenants."
        )
        metricsCountClients = client.createGauge(
                forType: Int.self,
                named: "\(Constants.APPLICATION.lowercased())_clients_count",
                helpText: "Current number of managed clients for all tenants."
        )
    }
}
