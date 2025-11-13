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
        // invalid the cookie
        response.cookies[Constants.COOKIE.NAME] = HTTPCookies.Value.defaultCookie(
            expires: Date().advanced(by: -1),
            withContent: "invalid"
        )

        // set the cookie domain
        response.cookies[Constants.COOKIE.NAME]?.domain = Constants.PUBLIC_DOMAIN

        if req.clientInfo?.mode == .interceptor {
            Log.info("Logout for interceptor mode", requestId: req.id)
            response.cookies[Constants.COOKIE.NAME]?.domain = tenant.config.interceptor?.cookieOrDomain
        } else {
            Log.info("Logout for oauth mode", requestId: req.id)
        }

        Log.info(
            """
                Finish logout \(jwt.subject.value) from tenant: \(tenant.name)
                , domain \(response.cookies[Constants.COOKIE.NAME]?.domain ?? "-")
                """, requestId: req.id)

        // remove authorisation headers
        response.headers.bearerAuthorization = nil

        // destroy the session (if any) and wipe tokens that still exists.
        req.session.destroy()
        await req.application.authCodeStorage?.wipe(tenant: tenant, subject: jwt.subject.value)

        // Log, metrics and return
        Log.info("Logout succeeded \(jwt.user) for \(tenant.name), redirect to \(locationRedirect)", requestId: req.id)
        Prometheus.main.logout?.inc(1, [
            ("redirect", locationRedirect),
            ("mode", req.clientInfo?.mode.rawValue ?? "unknown"),
            ("tenant", tenant.name)
        ])

        return response
    }
}
