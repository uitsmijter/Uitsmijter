import Foundation
import Vapor
import Logger

/// Actor responsible for handling authentication events consistently across the application.
///
/// This actor centralizes the handling of authentication events (login success/failure, logout)
/// by combining two operations that should always happen together:
/// 1. Recording Prometheus metrics
/// 2. Updating entity status (Kubernetes CRDs, denied attempts counter)
///
/// ## Usage
/// ```swift
/// // Record successful login
/// await req.application.authEventActor.recordLoginSuccess(
///     tenant: tenant.name,
///     client: clientInfo.client,
///     mode: clientInfo.mode.rawValue,
///     host: req.forwardInfo?.location.host ?? "unknown"
/// )
///
/// // Record failed login
/// await req.application.authEventActor.recordLoginFailure(
///     tenant: clientInfo.tenant?.name,
///     client: clientInfo.client,
///     mode: clientInfo.mode.rawValue,
///     host: req.forwardInfo?.location.host ?? "unknown"
/// )
///
/// // Record logout
/// await req.application.authEventActor.recordLogout(
///     tenant: tenant.name,
///     client: req.clientInfo?.client,
///     mode: req.clientInfo?.mode.rawValue ?? "unknown",
///     redirect: locationRedirect
/// )
/// ```
///
/// - Note: This actor replaces the pattern of calling Prometheus metrics and entity status updates separately.
/// - SeeAlso: GitHub Issue #78
@MainActor
final class AuthEventActor {
    /// Reference to entity storage for tracking denied attempts
    private let entityStorage: EntityStorage

    /// Reference to entity loader for triggering Kubernetes status updates
    private weak var entityLoader: EntityLoader?

    /// Initialize the auth event actor.
    ///
    /// - Parameters:
    ///   - entityStorage: The entity storage for tracking client metrics
    ///   - entityLoader: The entity loader for triggering Kubernetes CRD updates
    init(entityStorage: EntityStorage, entityLoader: EntityLoader?) {
        self.entityStorage = entityStorage
        self.entityLoader = entityLoader
    }

    /// Record a successful login event.
    ///
    /// This method:
    /// 1. Increments the Prometheus login success counter with labels
    /// 2. Triggers Kubernetes CRD status update for the tenant and client
    ///
    /// - Parameters:
    ///   - tenant: The tenant name where the login occurred
    ///   - client: The client used for login (nil for interceptor mode without client)
    ///   - mode: The authentication mode ("oauth" or "interceptor")
    ///   - host: The forwarded host from the request
    func recordLoginSuccess(
        tenant: String,
        client: UitsmijterClient?,
        mode: String,
        host: String
    ) async {
        // Record Prometheus metric
        Prometheus.main.loginSuccess?.inc(1, [
            ("forward_host", host),
            ("mode", mode),
            ("tenant", tenant)
        ])

        // Trigger Kubernetes CRD status update
        await entityLoader?.triggerStatusUpdate(for: tenant, client: client)

        Log.debug("Recorded login success for tenant: \(tenant), mode: \(mode)")
    }

    /// Record a failed login event.
    ///
    /// This method:
    /// 1. Increments the Prometheus login failure counter with labels
    /// 2. Increments the denied attempts counter for the client (if present)
    /// 3. Triggers Kubernetes CRD status update for the client
    ///
    /// - Parameters:
    ///   - tenant: The tenant name where the login was attempted (may be nil if tenant couldn't be determined)
    ///   - client: The client used for login attempt (nil for interceptor mode or if client not found)
    ///   - mode: The authentication mode ("oauth" or "interceptor")
    ///   - host: The forwarded host from the request
    func recordLoginFailure(
        tenant: String?,
        client: UitsmijterClient?,
        mode: String,
        host: String
    ) async {
        // Record Prometheus metric
        Prometheus.main.loginFailure?.inc(1, [
            ("forward_host", host),
            ("mode", mode),
            ("tenant", tenant ?? "unknown")
        ])

        // Increment denied login attempts counter for the client
        if let client = client {
            entityStorage.incrementDeniedAttempts(for: client.name)
            Log.debug("Incremented denied attempts for client: \(client.name)")

            // Trigger Kubernetes CRD status update for the client
            await entityLoader?.triggerClientStatusUpdate(for: client.name)
        }

        Log.debug("Recorded login failure for tenant: \(tenant ?? "unknown"), mode: \(mode)")
    }

    /// Record a logout event.
    ///
    /// This method:
    /// 1. Increments the Prometheus logout counter with labels
    /// 2. Triggers Kubernetes CRD status update for the tenant and client
    ///
    /// - Parameters:
    ///   - tenant: The tenant name where the logout occurred
    ///   - client: The client used (nil for interceptor mode without client)
    ///   - mode: The authentication mode ("oauth" or "interceptor")
    ///   - redirect: The redirect location after logout
    func recordLogout(
        tenant: String,
        client: UitsmijterClient?,
        mode: String,
        redirect: String
    ) async {
        // Record Prometheus metric
        Prometheus.main.logout?.inc(1, [
            ("redirect", redirect),
            ("mode", mode),
            ("tenant", tenant)
        ])

        // Trigger Kubernetes CRD status update
        await entityLoader?.triggerStatusUpdate(for: tenant, client: client)

        Log.debug("Recorded logout for tenant: \(tenant), mode: \(mode)")
    }
}
