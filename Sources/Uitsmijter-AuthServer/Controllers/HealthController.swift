import Foundation
import Vapor
import Logger

/// Controller providing health check and readiness probe endpoints.
///
/// The `HealthController` implements Kubernetes-style health probes for monitoring
/// the application's status. It provides two endpoints:
/// - `/health` - Liveness probe to check if the service is running
/// - `/health/ready` - Readiness probe to check if the service can accept traffic
///
/// These endpoints are typically used by orchestration systems like Kubernetes to
/// determine when to restart containers or route traffic to instances.
///
/// ## Route Registration
///
/// Routes are registered under the `/health` path group:
/// - `GET /health` - Returns HTTP 204 if healthy, HTTP 500 if unhealthy
/// - `GET /health/ready` - Returns HTTP 204 if ready, HTTP 417 if not ready
///
/// ## Health Checks
///
/// The controller verifies:
/// - AuthCodeStorage is initialized and healthy
/// - Critical system components are operational
///
/// ## Example
///
/// ```swift
/// // Register routes in configure.swift
/// try app.register(collection: HealthController())
///
/// // Kubernetes liveness probe
/// livenessProbe:
///   httpGet:
///     path: /health
///     port: 8080
///
/// // Kubernetes readiness probe
/// readinessProbe:
///   httpGet:
///     path: /health/ready
///     port: 8080
/// ```
///
/// - Note: This controller is `Sendable` and safe for concurrent access.
final class HealthController: RouteCollection, Sendable {

    /// Registers health check routes with the application.
    ///
    /// This method is called during application startup to register all health-related
    /// endpoints with the routing system. It creates a `/health` route group and adds
    /// both liveness and readiness probe handlers.
    ///
    /// - Parameter routes: The routes builder to register endpoints with.
    /// - Throws: Routing configuration errors (typically none for this controller).
    func boot(routes: RoutesBuilder) throws {
        let health = routes.grouped("health")
        health.get(use: { @Sendable (req: Request) async throws -> HTTPStatus in
            try await self.isHealthy(req)
        })
        health.get("ready", use: { @Sendable (req: Request) async throws -> HTTPStatus in
            try await self.isReady(req)
        })
    }

    /// Performs a liveness check to determine if the service is operational.
    ///
    /// This method implements a Kubernetes liveness probe, checking if the application
    /// is alive and able to serve requests. If this check fails, the orchestration system
    /// should restart the container.
    ///
    /// ## Health Criteria
    ///
    /// The service is considered healthy if:
    /// - The AuthCodeStorage component (if configured) reports healthy status
    /// - No critical system failures are detected
    ///
    /// ## Return Values
    ///
    /// - Returns HTTP 204 (No Content) if all checks pass
    /// - Returns HTTP 500 (Internal Server Error) if any component is unhealthy
    ///
    /// ## Failure Handling
    ///
    /// When AuthCodeStorage is unhealthy (e.g., Redis connection lost), the method:
    /// 1. Logs a critical error with the request ID for debugging
    /// 2. Returns HTTP 500 to signal the orchestrator to restart the pod
    ///
    /// - Parameter req: The incoming HTTP request containing application context.
    /// - Returns: HTTP status indicating health (204 = healthy, 500 = unhealthy).
    /// - Throws: Generally does not throw; returns status codes instead.
    @Sendable func isHealthy(_ req: Request) async throws -> HTTPStatus {
        // check AuthCodeStorage
        if let authCodeStorage = req.application.authCodeStorage {
            if await authCodeStorage.isHealthy() == false {
                Log.critical("AuthCodeStorage is not healthy", requestId: req.id)
                return .internalServerError
            }
        }
        return .noContent
    }

    /// Performs a readiness check to determine if the service can accept traffic.
    ///
    /// This method implements a Kubernetes readiness probe, checking if the application
    /// has completed initialization and is ready to serve requests. If this check fails,
    /// the orchestration system will not route traffic to this instance.
    ///
    /// ## Readiness Criteria
    ///
    /// The service is considered ready if:
    /// - AuthCodeStorage has been initialized (not nil)
    /// - If Redis is configured, the Redis connection is healthy
    /// - All health checks pass (via ``isHealthy(_:)``)
    ///
    /// ## Return Values
    ///
    /// - Returns HTTP 204 (No Content) if the service is fully ready
    /// - Returns HTTP 417 (Expectation Failed) if initialization is incomplete or Redis is not ready
    /// - Returns HTTP 500 (Internal Server Error) if health checks fail
    ///
    /// ## Startup Sequence
    ///
    /// During application startup, this endpoint will return 417 until:
    /// 1. AuthCodeStorage (Redis or in-memory) is initialized
    /// 2. If Redis is used, the connection is established and healthy
    /// 3. All health criteria are met
    ///
    /// This prevents the load balancer from sending requests before the application
    /// is fully initialized, avoiding errors during the startup phase.
    ///
    /// ## Redis Check
    ///
    /// Redis is only checked when the application is configured to use it (production/release mode).
    /// In development mode with in-memory storage, the Redis check is skipped.
    ///
    /// - Parameter req: The incoming HTTP request containing application context.
    /// - Returns: HTTP status indicating readiness (204 = ready, 417 = not ready, 500 = unhealthy).
    /// - Throws: May propagate errors from the health check.
    @Sendable func isReady(_ req: Request) async throws -> HTTPStatus {
        // Check if AuthCodeStorage is initialized
        if req.application.authCodeStorage == nil {
            return .expectationFailed
        }

        // Check if Redis is configured and healthy (only in production/release mode)
        // Redis is used when authCodeStorage is configured with .redis backend
        if let authCodeStorage = req.application.authCodeStorage {
            // The isHealthy check in authCodeStorage already validates Redis connectivity
            // but we want to fail early in readiness probe before accepting traffic
            if await authCodeStorage.isHealthy() == false {
                Log.info("Service not ready: AuthCodeStorage (Redis) is not healthy yet")
                return .expectationFailed
            }
        }

        // Perform full health check
        return try await isHealthy(req)
    }
}
