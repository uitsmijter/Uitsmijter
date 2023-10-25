import Foundation
import Vapor
import Metrics

final class MetricsController: RouteCollection {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let metrics = routes.grouped("metrics")
        metrics.get(use: getMetrics)
    }

    /// Returns all metrics
    func getMetrics(_ req: Request) throws -> EventLoopFuture<String> {
        // Only openmetrics can access this route
        if !(req.headers.first(name: "Accept") ?? "").contains("application/openmetrics-text") {
            Log.error(
                    """
                    Not allowed access to /metrics from
                     \(req.remoteAddress?.description ?? "no_adress")",
                     because of Accept header:
                     \(req.headers.first(name: "Accept") ?? "no accept header")
                    """, request: req

            )
            throw Abort(.notAcceptable, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        let promise = req.eventLoop.makePromise(of: String.self)
        try MetricsSystem.prometheus().collect(into: promise)
        return promise.futureResult
    }
}
