import Vapor
import Foundation

struct InterceptorController: RouteCollection {

    private let calendar = Calendar.current

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("interceptor")
        auth.get(use: doAuthentication)
    }

    /// Checks if a GET to /interceptor has a valid JWT
    /// otherwise it will forward to /login
    func doAuthentication(req: Request) async throws -> Response {

        let clientInfo = try getClientInfo(on: req)
        let tenant = try getTenant(of: clientInfo)

        // check if tenant allowed for interceptor
        try isAllowedForInterceptor(tenant: tenant)

        Log.info("""
                 Will verify token for \(clientInfo.requested.description)
                 from referer: \(req.clientInfo?.referer ?? "-")
                 on tenant: \(tenant.name)
                 """, request: req)

        guard clientInfo.validPayload != nil else {
            Log.info("Token is not valid for \(clientInfo.requested.description)", request: req)
            metricsInterceptorFailure?.inc(1, [
                ("requested_host", clientInfo.requested.host),
                ("tenant", tenant.name),
                ("reason", "INVALID_TOKEN")
            ])
            let forRequested = clientInfo.requested.description
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    ?? clientInfo.requested.description
            let redirect = req.redirect(
                    to: "\(clientInfo.requested.scheme)://"
                            + "\(tenant.config.interceptor?.domain ?? Constants.PUBLIC_DOMAIN)"
                            + "/login?for=\(forRequested)&mode=interceptor",
                    redirectType: .temporary
            )
            return redirect
        }

        // -- OK --
        Log.info("Token is valid for \(clientInfo.requested.description)", request: req)
        metricsInterceptorSuccess?.inc(1, [
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
    /// - Returns: a ClientInfo if set
    /// - Throws: badRequest error if ClientInfo is not present
    private func getClientInfo(on req: Request) throws -> ClientInfo {
        guard let clientInfo = req.clientInfo else {
            Log.error("Client request without clientInfo is not allowed in this context", request: req)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }
        return clientInfo
    }

    /// Get the tenant for a ClientInfo
    ///
    /// - Parameter clientInfo: A valid ClientInfo
    /// - Returns: a Tenant for the request is made
    /// - Throws: badRequest error if the tenant is not present
    private func getTenant(of clientInfo: ClientInfo) throws -> Tenant {
        guard let tenant = clientInfo.tenant else {
            Log.error("Client request without tenant is not allowed")
            throw Abort(.badRequest, reason: "ERRORS.NO_TENANT")
        }
        return tenant
    }

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
    fileprivate func isAllowedForInterceptor(tenant: Tenant) throws {
        if (tenant.config.interceptor?.enabled ?? true) == false {
            Log.info("Tenant \(tenant.name) is not allowed for interceptor mode.")
            metricsInterceptorFailure?.inc(1, [
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
            Log.critical("Refresh Payload can not be constructed from previous payload", request: request)
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

                    Log.info("Refresh token for user \(clientInfo.validPayload?.user ?? "-").", request: request)
                    payload.expiration.value = expirationDate

                    let refreshToken = try request.jwt.sign(payload)
                    response.headers.bearerAuthorization = BearerAuthorization(token: refreshToken)

                    response.cookies[Constants.COOKIE.NAME] = HTTPCookies.Value.defaultCookie(
                            expires: expirationDate,
                            withContent: refreshToken
                    )
                    response.cookies[Constants.COOKIE.NAME]?.domain =
                            clientInfo.tenant?.config.interceptor?.cookieOrDomain
                            ?? fallthroughCookieDomain(of: clientInfo)

                }
            }
        }
        return response
    }
}
