import Vapor
import Foundation
import Logger

/// Controller implementing Traefik ForwardAuth middleware functionality.
///
/// The `InterceptorController` provides authentication middleware integration with
/// Traefik's ForwardAuth mechanism. When Traefik receives a request to a protected
/// service, it forwards the request here for authentication verification before
/// allowing access.
///
/// ## How It Works
///
/// 1. Traefik intercepts incoming requests to protected services
/// 2. Traefik forwards request to `GET /interceptor` with original headers
/// 3. Controller verifies JWT token from cookie or Authorization header
/// 4. If valid: Returns HTTP 200, Traefik allows request through
/// 5. If invalid: Returns HTTP 307 redirect to login page
///
/// ## Route Registration
///
/// Registers:
/// - `GET /interceptor` - Validates authentication tokens for protected resources
///
/// ## Token Refresh
///
/// When a token is valid but approaching expiration (past 75% of its lifetime or
/// less than 2 hours remaining), the interceptor automatically:
/// 1. Validates the user is still authorized via the provider
/// 2. Generates a new token with extended expiration
/// 3. Returns it in the response headers and Set-Cookie
///
/// This ensures seamless session continuation without user intervention.
///
/// ## Security Features
///
/// - Tenant validation: Only tenants with `interceptor.enabled = true` are allowed
/// - Token expiration checking
/// - User revalidation before token refresh
/// - Metrics tracking for access attempts and failures
/// - Automatic redirect to login with proper return URL
///
/// ## Traefik Configuration Example
///
/// ```yaml
/// http:
///   middlewares:
///     auth:
///       forwardAuth:
///         address: "http://uitsmijter:8080/interceptor"
///         trustForwardHeader: true
///         authResponseHeaders:
///           - "Authorization"
///   routers:
///     protected-app:
///       rule: "Host(`app.example.com`)"
///       middlewares:
///         - auth
///       service: app-service
/// ```
///
/// - Note: This controller is designed specifically for Traefik ForwardAuth integration.
/// - SeeAlso: ``LoginController`` for the login flow that interceptor redirects to
/// - SeeAlso: [Traefik ForwardAuth Documentation](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
struct InterceptorController: RouteCollection {

    /// Calendar instance for date calculations during token refresh.
    private let calendar = Calendar.current

    /// Registers interceptor routes with the application.
    ///
    /// - Parameter routes: The routes builder to register endpoints with.
    /// - Throws: Routing configuration errors.
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("interceptor")
        auth.get(use: { @Sendable (req: Request) async throws -> Response in
            try await self.doAuthentication(req: req)
        })
    }

    /// Validates JWT authentication for Traefik ForwardAuth requests.
    ///
    /// This is the core interceptor method that Traefik calls to verify if a user
    /// is authenticated before allowing access to a protected resource.
    ///
    /// ## Request Flow
    ///
    /// 1. Extracts and validates client info from forwarded headers
    /// 2. Verifies the tenant allows interceptor mode
    /// 3. Checks for a valid, non-expired JWT token
    /// 4. If valid: Returns HTTP 200 with optionally refreshed token
    /// 5. If invalid: Returns HTTP 307 redirect to login page
    ///
    /// ## Success Response (HTTP 200)
    ///
    /// When authentication succeeds, Traefik receives HTTP 200 and forwards the
    /// original request to the backend service. If the token was refreshed, the
    /// response includes:
    /// - `Authorization` header with new bearer token
    /// - `Set-Cookie` header with new token cookie
    ///
    /// ## Failure Response (HTTP 307)
    ///
    /// When authentication fails, Traefik receives a redirect response directing
    /// the browser to:
    /// ```
    /// https://<interceptor-domain>/login?for=<original-url>&mode=interceptor
    /// ```
    ///
    /// ## Metrics
    ///
    /// Records either:
    /// - `Prometheus.main.interceptorSuccess` with tenant and requested host
    /// - `Prometheus.main.interceptorFailure` with tenant, requested host, and failure reason
    ///
    /// - Parameter req: The forwarded request from Traefik with X-Forwarded-* headers.
    /// - Returns: HTTP 200 response if authenticated, HTTP 307 redirect if not.
    /// - Throws: `Abort` errors for configuration or validation failures.
    @Sendable func doAuthentication(req: Request) async throws -> Response {

        let clientInfo = try req.requireClientInfo()
        let tenant = try req.requireTenant(from: clientInfo)

        // check if tenant allowed for interceptor
        try await isAllowedForInterceptor(tenant: tenant)

        Log.info("""
                 Will verify token for \(clientInfo.requested.description)
                 from referer: \(req.clientInfo?.referer ?? "-")
                 on tenant: \(tenant.name)
                 """, requestId: req.id)

        guard clientInfo.validPayload != nil else {
            Log.info("Token is not valid for \(clientInfo.requested.description)", requestId: req.id)
            Prometheus.main.interceptorFailure?.inc(1, [
                ("requested_host", clientInfo.requested.host),
                ("tenant", tenant.name),
                ("reason", "INVALID_TOKEN")
            ])
            let forRequested = clientInfo.requested.description
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                ?? clientInfo.requested.description
            let interceptorDomain = tenant.config.interceptor?.domain ?? Constants.PUBLIC_DOMAIN
            let redirect = req.redirect(
                to: "\(clientInfo.requested.scheme)://"
                    + interceptorDomain
                    + "/login?for=\(forRequested)&mode=interceptor",
                redirectType: .temporary
            )
            return redirect
        }

        // -- OK --
        Log.info("Token is valid for \(clientInfo.requested.description)", requestId: req.id)
        Prometheus.main.interceptorSuccess?.inc(1, [
            ("requested_host", clientInfo.requested.host),
            ("tenant", tenant.name)
        ])

        let response = Response.init(status: .ok)
        return try await refreshedToken(at: req, on: response, for: clientInfo)
    }

    // MARK: - Private functions
    /// Ensure that clientInfo is set
    ///
    /// - Parameter req: Request
    /// Get a fallback cookie domain if other methods didn't match
    ///
    /// - Parameter clientInfo: A valid ClientInfo
    /// - Returns: A String of the fallback domain
    private func fallthroughCookieDomain(of clientInfo: ClientInfo) -> String {
        URL(string: clientInfo.referer
                ?? clientInfo.requested.description
        )?.host ?? clientInfo.responsibleDomain
    }

    /// Check if the `Tenant` is allowed for interceptor mode
    ///
    /// - Parameter tenant: The tenant for the request
    /// - Throws: forbidden if tenant is not allowed
    fileprivate func isAllowedForInterceptor(tenant: Tenant) async throws {
        let isEnabled = tenant.config.interceptor?.enabled ?? true
        if isEnabled == false {
            Log.info("Tenant \(tenant.name) is not allowed for interceptor mode.")
            Prometheus.main.interceptorFailure?.inc(1, [
                ("tenant", tenant.name),
                ("reason", "TENANT_NOT_ALLOWED")
            ])
            throw Abort(.forbidden, reason: "ERRORS.TENANT_NOT_ALLOWED")
        }
    }

    /// Should refresh the token?
    /// Refresh should be begin after 2/3 is passed
    private func refreshedToken(
        at request: Request,
        on response: Response,
        for clientInfo: ClientInfo
    ) async throws -> Response {
        guard var payload = clientInfo.validPayload else {
            Log.critical("Refresh Payload can not be constructed from previous payload", requestId: request.id)
            throw Abort(.internalServerError, reason: "ERRORS.EXPECTED_VALUE_UNSET")
        }
        let minutesToLive = payload.expiration.value.timeIntervalSince(Date()) / 60 / 60
        let expirationDays = Double(Constants.COOKIE.EXPIRATION_DAYS) * 0.75
        if let refreshDate = calendar.date(
            byAdding: .day,
            value: Int(expirationDays.rounded(.down)),
            to: payload.expiration.value
        ) {
            if Date().timeIntervalSince1970 > refreshDate.timeIntervalSince1970 || minutesToLive < 2 {
                if let expirationDate = calendar.date(
                    byAdding: .day,
                    value: Constants.COOKIE.EXPIRATION_DAYS,
                    to: Date()
                ) {

                    // is still valid?
                    guard let username = clientInfo.validPayload?.user else {
                        throw Abort(.notAcceptable, reason: "ERRORS.EXPECTED_VALUE_UNSET")
                    }
                    if try await UserValidation.isStillValid(username: username, on: request) == false {
                        // 1.0 : show error
                        // 1.x : redirect to login
                        throw Abort(.forbidden, reason: "ERRORS.INVALIDATE")
                    }

                    Log.info("Refresh token for user \(clientInfo.validPayload?.user ?? "-").", requestId: request.id)
                    payload.expiration.value = expirationDate

                    let refreshToken = try request.jwt.sign(payload)
                    response.headers.bearerAuthorization = BearerAuthorization(token: refreshToken)

                    response.cookies[Constants.COOKIE.NAME] = HTTPCookies.Value.defaultCookie(
                        expires: expirationDate,
                        withContent: refreshToken
                    )
                    let cookieDomain = clientInfo.tenant?.config.interceptor?.cookieOrDomain
                        ?? fallthroughCookieDomain(of: clientInfo)
                    response.cookies[Constants.COOKIE.NAME]?.domain = cookieDomain

                }
            }
        }
        return response
    }
}
