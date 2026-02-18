import Foundation
import Vapor
import JWT
import Logger

struct LogoutController: RouteCollection {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let logout = routes.grouped("logout")
        logout.get(use: { @Sendable (req: Request) async throws -> View in
            try await self.startLogoutRefresh(req: req)
        })
        logout.post(use: { @Sendable (req: Request) async throws -> Response in
            try await self.doLogout(req: req)
        })
        logout.get(["finalize"], use: { @Sendable (req: Request) async throws -> Response in
            try await self.doLogout(req: req)
        })
    }

    /// Start the logout progress
    /// Logout do need a refresh to retrieve the cookie.
    /// Logout finalize will return to `post_logout_redirect_uri`
    ///
    /// - Parameter req: Request
    /// - Returns: A view that shows a message and redirects to the /logout/finalize route
    /// - Throws: an Vapor.Error if rendering fails
    @Sendable func startLogoutRefresh(req: Request) async throws -> View {
        let post_logout_redirect_uri: String? = try? req.query.get(at: "post_logout_redirect_uri")

        let jwt = try? await req.jwt.verify(as: Payload.self)
        var tenant: Tenant?
        if let jwt {
            let tenantName = jwt.tenant
            tenant = await Tenant.find(in: req.application.entityStorage, name: tenantName)
        }
        Log.info(
            """
                Start logout \(jwt?.subject.value ?? "-") from tenant: \(tenant?.name ?? "-")
                """, requestId: req.id)

        return try await req.view.render(
            Template.getPath(page: "logout", request: req),
            PageProperties(
                title: "Logout",
                requestUri: post_logout_redirect_uri ?? req.headers.first(name: "Referer") ?? "/",
                serviceUrl: "//" + (req.headers.first(name: "Host") ?? Constants.PUBLIC_DOMAIN),
                requestInfo: req.requestInfo,
                tenant: tenant
            )
        )
    }

    /// Logs the user out and invalids the cookie, then return to the Refers `location`
    @Sendable func doLogout(req: Request) async throws -> Response {
        // get the location parameter for redirect back to the client
        let locationRedirect: String = try req.query.get(at: "location") ?? "/"

        // to logout a user must have a valid token
        let jwt = try await req.jwt.verify(as: Payload.self)

        // The tenant with whom the user is registered
        let tenantName = jwt.tenant
        guard let tenant = await Tenant.find(in: req.application.entityStorage, name: tenantName) else {
            throw Abort(.badRequest, reason: "LOGOUT.ERRORS.NO_TENANT")
        }

        // construct the redirect
        let response = req.redirect(to: locationRedirect)

        // Invalidate cookies on all relevant domains.
        // The browser may hold separate cookies for the interceptor domain
        // (e.g. .ops.example.com) and the OAuth host (e.g. login.ops.example.com).
        // We must send a Set-Cookie header for each distinct domain.
        //
        // The first domain uses response.cookies (survives SessionsMiddleware's
        // dictionary round-trip). Additional domains are stored in request storage
        // and appended by ExtraCookiesMiddleware after the session middleware runs.
        let domains = cookieDomainsToInvalidate(req: req, tenant: tenant)
        if let primaryDomain = domains.first {
            response.cookies[Constants.COOKIE.NAME] = HTTPCookies.Value.defaultCookie(
                expires: Date().advanced(by: -1),
                withContent: "invalid"
            )
            response.cookies[Constants.COOKIE.NAME]?.domain = primaryDomain
        }
        for domain in domains.dropFirst() {
            var cookie = HTTPCookies.Value.defaultCookie(
                expires: Date().advanced(by: -1),
                withContent: "invalid"
            )
            cookie.domain = domain
            req.extraSetCookieHeaders.append(
                cookie.serialize(name: Constants.COOKIE.NAME)
            )
        }

        Log.info(
            """
                Finish logout \(jwt.subject.value) from tenant: \(tenant.name)
                , domains \(domains.joined(separator: ", "))
                """, requestId: req.id)

        // remove authorisation headers
        response.headers.bearerAuthorization = nil

        // Debug: Count sessions before wipe
        if let storage = req.application.authCodeStorage {
            let sessionsBefore = await storage.count(tenant: tenant, type: .refresh)
            Log.debug("Session count before wipe: \(sessionsBefore) for tenant: \(tenant.name)", requestId: req.id)
        }

        // destroy the session (if any) and wipe tokens that still exists.
        req.session.destroy()
        await req.application.authCodeStorage?.wipe(tenant: tenant, subject: jwt.subject.value)

        // Debug: Count sessions after wipe
        if let storage = req.application.authCodeStorage {
            let sessionsAfter = await storage.count(tenant: tenant, type: .refresh)
            Log.debug("Session count after wipe: \(sessionsAfter) for tenant: \(tenant.name)", requestId: req.id)
        }

        // Record logout event (Prometheus metrics + entity status update)
        await req.application.authEventActor.recordLogout(
            tenant: tenant.name,
            client: req.clientInfo?.client,
            mode: req.clientInfo?.mode.rawValue ?? "unknown",
            redirect: locationRedirect
        )

        // Log and return
        Log.info("Logout succeeded \(jwt.user) for \(tenant.name), redirect to \(locationRedirect)", requestId: req.id)

        return response
    }

    /// Collects all distinct cookie domains that need invalidation.
    ///
    /// When a tenant has an interceptor domain configured (e.g. `.ops.example.com`)
    /// and the OAuth login page runs on a different host (e.g. `login.ops.example.com`),
    /// the browser holds two separate cookies with the same name but different domains.
    /// Both must be invalidated for a complete logout.
    ///
    /// - Parameters:
    ///   - req: The current request
    ///   - tenant: The tenant the user is logging out from
    /// - Returns: An array of unique domain strings to invalidate
    private func cookieDomainsToInvalidate(req: Request, tenant: Tenant) -> [String] {
        var domains: [String] = []

        // Interceptor cookie domain (e.g. ".ops.example.com")
        if let interceptorDomain = tenant.config.interceptor?.cookieOrDomain {
            domains.append(interceptorDomain)
        }

        // Request host domain (the OAuth login host, e.g. "login.ops.example.com")
        let hostDomain = req.forwardInfo?.location.host
            ?? req.headers.first(name: "host")
            ?? Constants.PUBLIC_DOMAIN
        if !domains.contains(hostDomain) {
            domains.append(hostDomain)
        }

        // Fallback: ensure at least one domain is present
        if domains.isEmpty {
            domains.append(Constants.PUBLIC_DOMAIN)
        }

        return domains
    }
}
