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

        // Verify the JWT if present. Some browsers (notably WebKit/Safari) may
        // not send SameSite=Strict cookies on meta-refresh navigations, so the
        // token cookie can be absent. We still want to redirect and clean up.
        let jwt = try? await req.jwt.verify(as: Payload.self)

        // Resolve the tenant — prefer the JWT claim, fall back to the tenant
        // already resolved by RequestClientMiddleware from the location param.
        let tenant: Tenant?
        if let jwt {
            tenant = await Tenant.find(
                in: req.application.entityStorage, name: jwt.tenant
            )
        } else {
            Log.warning(
                "Logout without valid JWT, falling back to clientInfo tenant",
                requestId: req.id
            )
            tenant = req.clientInfo?.tenant
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
        if let tenant {
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
        }

        Log.info(
            "Finish logout \(jwt?.subject.value ?? "-") from tenant: \(tenant?.name ?? "-")",
            requestId: req.id
        )

        // remove authorisation headers
        response.headers.bearerAuthorization = nil

        // destroy the session (if any) and wipe tokens that still exist.
        req.session.destroy()
        if let tenant, let subject = jwt?.subject.value {
            await req.application.authCodeStorage?.wipe(
                tenant: tenant, subject: subject
            )
        }

        // Record logout event (Prometheus metrics + entity status update)
        await req.application.authEventActor.recordLogout(
            tenant: tenant?.name ?? "unknown",
            client: req.clientInfo?.client,
            mode: req.clientInfo?.mode.rawValue ?? "unknown",
            redirect: locationRedirect
        )

        Log.info(
            "Logout succeeded for \(tenant?.name ?? "-"), redirect to \(locationRedirect)",
            requestId: req.id
        )

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

        // OAuth cookie domain — resolved through the Helm cookieDomain mapping
        let host = req.forwardInfo?.location.host
            ?? req.headers.first(name: "host")
            ?? Constants.PUBLIC_DOMAIN
        let oauthDomain = CookieDomainMapping.resolve(for: host)
        if !domains.contains(oauthDomain) {
            domains.append(oauthDomain)
        }

        // Fallback: ensure at least one domain is present
        if domains.isEmpty {
            domains.append(Constants.PUBLIC_DOMAIN)
        }

        return domains
    }
}
