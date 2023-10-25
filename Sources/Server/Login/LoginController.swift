import Foundation
import Vapor
import JWT

struct LoginController: RouteCollection {

    private let calendar = Calendar.current

    /// Errors that can be printed on the login form
    enum FrontendErrors: String {
        case FORM_NOT_PARSEABLE = "LOGIN.ERRORS.FORM_NOT_PARSEABLE"
        case CONSTRUCT_DATE_ERROR = "LOGIN.ERRORS.CONSTRUCT_DATE_ERROR"
        case MISSING_LOCATION = "LOGIN.ERRORS.MISSING_LOCATION"
        case NO_TENANT = "LOGIN.ERRORS.NO_TENANT"
        case CLIENT_NOT_FOUND = "LOGIN.ERRORS.NO_CLIENT"
        case WRONG_CREDENTIALS = "LOGIN.ERRORS.WRONG_CREDENTIALS"
    }

    /// Function to render the login view. It is used multiple times in this route
    ///
    /// - Parameters:
    ///   - req: Current request
    ///   - status: HTTPResponseStatus that should be returned
    ///   - error: An descriptive error shown on tha page
    ///   - pageProperties:
    /// - Returns: Vapor Response
    /// - Throws: An error if the login page can not render
    static func renderLoginView(
            on req: Request,
            status: HTTPResponseStatus,
            error: FrontendErrors? = nil,
            props pageProperties: PageProperties? = nil
    ) async throws -> Response {
        guard let clientInfo = req.clientInfo else {
            Log.info("""
                     Render LoginView was called without a clientInfo object.
                     It is likely that the application is not set up properly.
                     """, request: req)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        let view: View = try await req.view.render(
                Template.getPath(page: "login", request: req),
                pageProperties ?? PageProperties(
                        title: "Login",
                        error: error?.rawValue,
                        serviceUrl: "//" + clientInfo.serviceUrl,
                        requestInfo: req.requestInfo
                )
        )
        return try await view.encodeResponse(status: status, for: req)
    }

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let login = routes.grouped("login")
        login.get(use: getLoginMask)
        login.post(use: doLogin)
    }

    // MARK: - Route

    /// Show the login mask of the tenant or the default mask
    /// QueryParameter:
    ///   - for
    ///   - mode
    ///
    /// - Parameter req: Request
    /// - Returns: A LoginForm HTML Response
    /// - Throws: an error if parameter `for` is not set
    func getLoginMask(req: Request) async throws -> Response {
        guard let clientInfo = req.clientInfo else {
            Log.error("Client request without clientInfo is not allowed in this context", request: req)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }
        let requestUri: String? = try req.query.get(at: "for")

        if let payload = clientInfo.validPayload, clientInfo.isExpired() == false {
            if let tenant = clientInfo.tenant, tenant.config.silent_login == true {
                Log.info("User '\(payload.subject.value)' is already logged in.", request: req)
                return req.redirect(
                        to: requestUri ?? ("//" + clientInfo.serviceUrl)
                )
            }
        }

        return try await LoginController.renderLoginView(on: req, status: .ok, error: nil, props: PageProperties(
                title: "Login",
                requestUri: requestUri ?? ("//" + clientInfo.serviceUrl),
                serviceUrl: "",
                mode: clientInfo.mode,
                tenant: clientInfo.tenant
        ))
    }

    // MARK: - Private functions

    /// Initiate a login provider
    ///
    /// - Parameters:
    ///   - tenant: the current tenant
    ///   - form: a filled login form
    /// - Returns: a Provider
    /// - Throws: an error if the provider can't be constructed
    private func userLoginProvider(for tenant: Tenant, login form: LoginForm) async throws -> JavaScriptProvider {
        let providerInterpreter = JavaScriptProvider()
        try providerInterpreter.loadProvider(script: tenant.config.providers.joined(separator: "\n"))
        try await providerInterpreter.start(
                class: .userLogin,
                arguments: JSInputCredentials(username: form.username, password: form.password)
        )
        return providerInterpreter
    }

    /// Call this function when a user cannot be logged in
    /// A new login view will be presented.
    ///
    /// - Parameters:
    ///   - req: The current `Request`
    ///   - login: the filled login form
    /// - Returns: a `Response`
    /// - Throws: an error if the login view can not be rendered.
    private func canNotLoginResponse(on req: Request, form login: LoginForm) async throws -> Response {
        guard let clientInfo = req.clientInfo else {
            Log.error("Call canNotLoginResponse without clientInfo is not allowed in this context", request: req)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        Log.info(
                "Can not login user \(login.username) to \(req.forwardInfo?.location.description ?? "-")",
                request: req
        )

        metricsLoginFailure?.inc(1, [
            ("forward_host", req.forwardInfo?.location.host ?? "unknown"),
            ("mode", clientInfo.mode.rawValue),
            ("tenant", clientInfo.tenant?.name ?? "unknown")
        ])

        if let host = req.forwardInfo?.location.host {
            req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: host)
        }
        return try await LoginController.renderLoginView(
                on: req,
                status: .forbidden,
                error: .WRONG_CREDENTIALS,
                props: PageProperties(
                        title: "Login",
                        error: LoginController.FrontendErrors.WRONG_CREDENTIALS.rawValue,
                        requestUri: login.location,
                        serviceUrl: "//" + clientInfo.serviceUrl,
                        payload: nil,
                        mode: clientInfo.mode,
                        requestInfo: req.requestInfo,
                        tenant: clientInfo.tenant
                )
        )
    }

    /// Construct a `Date` that is `EXPIRATION_DAYS` in the future.
    ///
    /// - Returns: A `Date` that is in the future and represents the date when a token gets invalid
    private func getExpirationDate() -> Date? {
        calendar.date(
                byAdding: .day,
                value: Constants.COOKIE.EXPIRATION_DAYS,
                to: Date()
        )
    }

    /// Ensures that a given location is allowed on the current client
    ///
    /// - Parameters:
    ///   - request: The current `Request`
    ///   - redirect: A redirect location wrapped in `RedirectUriProtocol`
    /// - Throws:
    ///    - A Vapor Error if the client os not in the clientInfo: `NO_CLIENT`
    ///    - A Vapor Error if the redirect is not allowed: `REDIRECT_MISMATCH`
    func ensureRedirectIsAllowed(on request: Request, redirect: RedirectUriProtocol) throws {
        guard let clientInfo = request.clientInfo else {
            Log.error("Client request without clientInfo is not allowed in this context", request: request)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        // if interceptor pass early - we allow every redirect
        if clientInfo.mode == .interceptor {
            Log.debug("Check redirect for interceptor:\(redirect.redirect_uri)", request: request)
            return
        }
        // if redirect points to server url pass early - we allow redirects to ourself, eg /authorise
        if let origin = request.headers.first(name: "Origin") {
            Log.info("Check if redirect is on same domain: \(origin)", request: request)
            if redirect.redirect_uri.absoluteString.starts(with: origin) {
                Log.info("Pass redirect check, because request it is on same domain", request: request)
                return
            }
        }

        // if oauth
        // check client is there
        guard let client = clientInfo.client else {
            Log.error("No client was detected for login.", request: request)
            throw Abort(.badRequest, reason: "ERRORS.NO_CLIENT")
        }
        Log.debug("Check redirect for oauth: \(redirect.redirect_uri) on client: \(client.name)", request: request)

        do {
            try client.checkedRedirect(for: redirect)
        } catch {
            Log.error("""
                      Redirect to \(redirect.redirect_uri) is not allowed
                      on client \(client.name) [\(clientInfo.tenant?.name ?? "-")]
                      """, request: request)
            throw Abort(.forbidden, reason: "ERRORS.REDIRECT_MISMATCH")
        }
    }

    /// do the login with credentials from the login-form and check if the user is valid.
    /// The response will forward to the `location` with a JWT
    func doLogin(req: Request) async throws -> Response {
        guard let clientInfo = req.clientInfo else {
            Log.error("Client request without clientInfo is not allowed in this context", request: req)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        guard let tenant = clientInfo.tenant else {
            throw Abort(.badRequest, reason: "ERRORS.MISSING_TENANT")
        }

        // user has to send a correct login form
        guard let loginForm = try? req.content.decode(LoginForm.self) else {
            return try await LoginController.renderLoginView(on: req, status: .badRequest, error: .FORM_NOT_PARSEABLE)
        }
        Log.info("Attempt login \(loginForm.username)", request: req)

        metricsLoginAttempts?.observe(1, .init([
            ("forward_host", req.forwardInfo?.location.host ?? "unknown"),
            ("mode", clientInfo.mode.rawValue),
            ("tenant", tenant.name)
        ]))

        // Check if redirect is allowed
        let redirectLocation: String = req.headers.first(name: "X-Forwarded-Uri") ?? loginForm.location
        try ensureRedirectIsAllowed(on: req, redirect: RedirectUri(redirectLocation))

        // redirect must be a url and will be enrich with information to distingush that this redir is from
        // the login form.
        guard let redirectLocationUrl: URL = URL(string: redirectLocation) else {
            throw Abort(.badRequest, reason: "ERRORS.REDIRECT_NOT_URL")
        }
        let loginSession = LoginSession(loginId: UUID())
        do {
            try req.application.authCodeStorage?.push(loginId: loginSession)
        } catch {
            Log.error("Can not save loginid.", request: req)
        }

        let additionalQueryItem = URLQueryItem(name: "loginid", value: loginSession.loginId.uuidString)
        let redirectTargetLocation = redirectLocationUrl.path.starts(with: "/authorize") == true
                ? redirectLocationUrl.appending(queryItems: [additionalQueryItem]).absoluteString
                : redirectLocationUrl.absoluteString

        // use a provider to check login requests
        let providerInterpreter = try await userLoginProvider(for: tenant, login: loginForm)

        // Ask the provider if the user can login
        if providerInterpreter.canLogin() == false {
            return try await canNotLoginResponse(on: req, form: loginForm)
        }

        // get the committed subject
        let providedSubject: SubjectProtocol = providerInterpreter.getSubject(loginHandle: loginForm.username)

        // get users profile from provider
        let profile: CodableProfile? = providerInterpreter.getProfile()
        if profile == nil {
            Log.error("Can not get profile of \(loginForm.username)", request: req)
        }

        // get users role from provider
        let role = providerInterpreter.getRole()

        // create jwt
        guard let expirationDate = getExpirationDate() else {
            return try await LoginController.renderLoginView(
                    on: req,
                    status: .internalServerError,
                    error: .CONSTRUCT_DATE_ERROR
            )
        }
        let responsibleDomainHash = ResponsibilityDomain.getResponsibilityDomain(on: req, for: clientInfo)

        let payload = Payload(
                subject: providedSubject.subject,
                expiration: .init(value: expirationDate),
                tenant: tenant.name,
                responsibility: responsibleDomainHash.hash,
                role: role,
                user: loginForm.username,
                profile: profile
        )
        let token = try req.jwt.sign(payload)

        Log.info("Redirect to \(redirectTargetLocation)", request: req)
        let response = req.redirect(to: redirectTargetLocation, redirectType: .normal)

        // set the cookie only for the request domain!
        var cookie = HTTPCookies.Value.defaultCookie(
                expires: expirationDate,
                withContent: token
        )

        if clientInfo.mode == .interceptor {
            cookie.domain = tenant.config.interceptor?.cookieOrDomain
                    ?? req.forwardInfo?.location.host
                    ?? Constants.PUBLIC_DOMAIN
        } else {
            cookie.domain = req.forwardInfo?.location.host ?? req.headers.first(name: "host") ?? Constants.PUBLIC_DOMAIN
        }
        Log.debug("Set cookie to domain: \(cookie.domain ?? "-")", request: req)
        response.cookies[Constants.COOKIE.NAME] = cookie

        // Success!
        Log.info("""
                 Login succeeded \(loginForm.username)
                 to \(req.forwardInfo?.location.host ?? "//")\(req.forwardInfo?.location.path ?? "/")
                 """,
                request: req
        )
        Log.audit.info("\(providedSubject.subject) on \(cookie.domain ?? "-")")

        metricsLoginSuccess?.inc(1, [
            ("forward_host", req.forwardInfo?.location.host ?? "unknown"),
            ("mode", clientInfo.mode.rawValue),
            ("tenant", tenant.name)
        ])

        return response
    }
}
