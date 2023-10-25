import Foundation
import Vapor
import JWT

struct LogoutController: RouteCollection {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let logout = routes.grouped("logout")
        logout.get(use: startLogoutRefresh)
        logout.post(use: doLogout)
        logout.get(["finalize"], use: doLogout)
    }

    /// Start the logout progress
    /// Logout do need a refresh to retrieve the cookie.
    /// Logout finalize will return to `post_logout_redirect_uri`
    ///
    /// - Parameter req: Request
    /// - Returns: A view that shows a message and redirects to the /logout/finalize route
    /// - Throws: an Vapor.Error if rendering fails
    func startLogoutRefresh(req: Request) async throws -> View {
        let post_logout_redirect_uri: String? = try? req.query.get(at: "post_logout_redirect_uri")

        let jwt = try? req.jwt.verify(as: Payload.self)
        var tenant: Tenant?
        if let jwt {
            tenant = Tenant.find(name: jwt.tenant)
        }
        Log.info(
                """
                Start logout \(jwt?.subject.value ?? "-") from tenant: \(tenant?.name ?? "-")
                """, request: req)

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
    func doLogout(req: Request) async throws -> Response {
        // get the location parameter for redirect back to the client
        let locationRedirect: String = try req.query.get(at: "location") ?? "/"

        // to logout a user must have a valid token
        let jwt = try req.jwt.verify(as: Payload.self)

        // The tenant with whom the user is registered
        guard let tenant = Tenant.find(name: jwt.tenant) else {
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
            Log.info("Logout for interceptor mode", request: req)
            response.cookies[Constants.COOKIE.NAME]?.domain = tenant.config.interceptor?.cookieOrDomain
        } else {
            Log.info("Logout for oauth mode", request: req)
        }

        Log.info(
                """
                Finish logout \(jwt.subject.value) from tenant: \(tenant.name)
                , domain \(response.cookies[Constants.COOKIE.NAME]?.domain ?? "-")
                """, request: req)

        // remove authorisation headers
        response.headers.bearerAuthorization = nil

        // destroy the session (if any) and wipe tokens that still exists.
        req.session.destroy()
        req.application.authCodeStorage?.wipe(tenant: tenant, subject: jwt.subject.value)

        // Log, metrics and return
        Log.info("Logout succeeded \(jwt.user) for \(tenant.name), redirect to \(locationRedirect)", request: req)
        metricsLogout?.inc(1, [
            ("redirect", locationRedirect),
            ("mode", req.clientInfo?.mode.rawValue ?? "unknown"),
            ("tenant", tenant.name)
        ])

        return response
    }
}
