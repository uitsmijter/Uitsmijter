import Foundation
import Vapor
import Metrics
import Logger

/// Controller exposing Prometheus-compatible application metrics.
///
/// The `MetricsController` provides an endpoint for collecting application metrics
/// in OpenMetrics/Prometheus format. This enables monitoring, alerting, and observability
/// through tools like:
/// - Prometheus
/// - Grafana
/// - Datadog
/// - CloudWatch
/// - Any OpenMetrics-compatible monitoring system
///
/// ## Security
///
/// The metrics endpoint is protected and only accepts requests with the proper
/// `Accept` header (`application/openmetrics-text`). This prevents casual browsing
/// of potentially sensitive operational metrics while allowing legitimate monitoring
/// tools to collect data.
///
/// Unauthorized access attempts are:
/// - Logged with the requesting IP address
/// - Rejected with HTTP 406 (Not Acceptable)
///
/// ## Route Registration
///
/// Registers:
/// - `GET /metrics` - Returns metrics in OpenMetrics text format
///
/// ## Metrics Format
///
/// The endpoint returns metrics in OpenMetrics text format:
/// ```
/// # HELP http_requests_total Total HTTP requests
/// # TYPE http_requests_total counter
/// http_requests_total{method="GET",status="200"} 1234
///
/// # HELP auth_attempts_total Authentication attempts
/// # TYPE auth_attempts_total counter
/// auth_attempts_total{result="success"} 567
/// auth_attempts_total{result="failure"} 12
/// ```
///
/// ## Example
///
/// ```swift
/// // Register routes in configure.swift
/// try app.register(collection: MetricsController())
///
/// // Prometheus scrape config
/// scrape_configs:
///   - job_name: 'uitsmijter'
///     static_configs:
///       - targets: ['localhost:8080']
///     metrics_path: /metrics
/// ```
///
/// - Note: This controller is `Sendable` and safe for concurrent access.
/// - SeeAlso: ``Monitoring/Prometheus`` for metric registration
final class MetricsController: RouteCollection, Sendable {

    /// Registers metrics routes with the application.
    ///
    /// This method is called during application startup to register the `/metrics`
    /// endpoint with the routing system.
    ///
    /// - Parameter routes: The routes builder to register endpoints with.
    /// - Throws: Routing configuration errors (typically none for this controller).
    func boot(routes: RoutesBuilder) throws {
        let metrics = routes.grouped("metrics")
        metrics.get(use: { @Sendable (req: Request) throws -> EventLoopFuture<String> in
            try self.getMetrics(req)
        })
    }

    /// Collects and returns all application metrics in OpenMetrics format.
    ///
    /// This method validates the request has the proper `Accept` header, then collects
    /// all registered Prometheus metrics and returns them in text format. The collection
    /// is asynchronous to avoid blocking the event loop during metric aggregation.
    ///
    /// ## Security Validation
    ///
    /// Only requests with `Accept: application/openmetrics-text` header are accepted.
    /// This ensures only legitimate monitoring tools can access metrics, preventing:
    /// - Accidental exposure through web browsers
    /// - Unauthorized metric scraping
    /// - Information disclosure to attackers
    ///
    /// Rejected requests are logged with:
    /// - Remote IP address
    /// - Accept header value
    /// - Request ID for correlation
    ///
    /// ## Async Collection
    ///
    /// Metrics are collected asynchronously using Vapor's `EventLoopFuture` to avoid
    /// blocking the event loop. The Prometheus client aggregates metrics from all
    /// registered counters, gauges, histograms, and summaries.
    ///
    /// ## Example Response
    ///
    /// ```
    /// # HELP http_requests_total Total HTTP requests
    /// # TYPE http_requests_total counter
    /// http_requests_total{method="GET",endpoint="/authorize"} 1523
    /// http_requests_total{method="POST",endpoint="/token"} 891
    /// ```
    ///
    /// - Parameter req: The incoming HTTP request to validate and use for collection.
    /// - Returns: An `EventLoopFuture` that will resolve to the metrics text when collection completes.
    /// - Throws: `Abort(.notAcceptable)` if the `Accept` header is missing or incorrect.
    @Sendable func getMetrics(_ req: Request) throws -> EventLoopFuture<String> {
        // Only openmetrics can access this route
        if !(req.headers.first(name: "Accept") ?? "").contains("application/openmetrics-text") {
            Log.error(
                """
                Not allowed access to /metrics from \(req.remoteAddress?.description ?? "no_address"), \
                because of Accept header: \(req.headers.first(name: "Accept") ?? "no accept header")
                """, requestId: req.id
            )
            throw Abort(.notAcceptable, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        let promise = req.eventLoop.makePromise(of: String.self)
        try MetricsSystem.prometheus().collect(into: promise)
        return promise.futureResult
    }
}
