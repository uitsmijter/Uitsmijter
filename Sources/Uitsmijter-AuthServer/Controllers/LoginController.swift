import Foundation
import Vapor
import JWT
import Logger

// swiftlint:disable:next orphaned_doc_comment
/// Controller handling user authentication through login forms.
///
/// The `LoginController` manages the complete user login flow for Uitsmijter,
/// including:
/// - Displaying tenant-specific login forms
/// - Processing login credentials through JavaScript providers
/// - Validating user authentication
/// - Generating JWT tokens upon successful authentication
/// - Setting secure cookies for session management
/// - Handling silent login scenarios
/// - Redirecting to appropriate targets after login
///
/// ## Authentication Flow
///
/// 1. **GET /login** - User requests login form with `?for=<redirect_uri>` parameter
/// 2. Form displays with tenant-specific branding and styling
/// 3. **POST /login** - User submits credentials (username, password)
/// 4. Controller validates credentials through JavaScript provider
/// 5. On success: Generates JWT, sets cookie, redirects to target
/// 6. On failure: Re-displays form with error message
///
/// ## Route Registration
///
/// Registers:
/// - `GET /login` - Displays the login form
/// - `POST /login` - Processes login credentials
///
/// ## Silent Login
///
/// If a tenant has `silent_login` enabled and the user already has a valid token,
/// the GET request automatically redirects to the target URL without showing the form.
///
/// ## Security Features
///
/// - Redirect URI validation against client configuration
/// - PKCE support for OAuth flows
/// - Secure cookie configuration with proper domain scoping
/// - Password validation through tenant-specific providers
/// - Login attempt tracking and metrics
///
/// ## Example
///
/// ```swift
/// // Register routes in configure.swift
/// try app.register(collection: LoginController())
///
/// // User flow
/// GET /login?for=https://app.example.com/dashboard&mode=oauth
/// -> Shows login form
/// POST /login
/// -> Validates credentials, generates token, redirects
/// ```
///
/// - Note: This controller works in both OAuth and Interceptor modes.
/// - SeeAlso: ``JavaScriptProvider`` for credential validation
/// - SeeAlso: ``LoginForm`` for the form data structure
/// - SeeAlso: ``PageProperties`` for template rendering context
// swiftlint:disable:next type_body_length
struct LoginController: RouteCollection, OAuthControllerProtocol {

    /// Calendar instance for date calculations.
    ///
    /// Used for calculating token expiration dates and refresh intervals.
    private let calendar = Calendar.current

    /// User-facing error messages displayed on the login form.
    ///
    /// These error codes are used as translation keys in the tenant's language files.
    /// Each error corresponds to a specific failure scenario during the login process.
    ///
    /// ## Cases
    ///
    /// - **FORM_NOT_PARSEABLE**: The submitted form data could not be decoded
    /// - **CONSTRUCT_DATE_ERROR**: Failed to calculate token expiration date
    /// - **MISSING_LOCATION**: Required redirect location parameter is missing
    /// - **NO_TENANT**: No tenant could be identified for the request
    /// - **CLIENT_NOT_FOUND**: The specified OAuth client does not exist
    /// - **WRONG_CREDENTIALS**: Username or password is incorrect
    ///
    /// - Note: The raw values are translation keys, not user-visible text.
    enum FrontendErrors: String {
        case FORM_NOT_PARSEABLE = "LOGIN.ERRORS.FORM_NOT_PARSEABLE"
        case CONSTRUCT_DATE_ERROR = "LOGIN.ERRORS.CONSTRUCT_DATE_ERROR"
        case MISSING_LOCATION = "LOGIN.ERRORS.MISSING_LOCATION"
        case NO_TENANT = "LOGIN.ERRORS.NO_TENANT"
        case CLIENT_NOT_FOUND = "LOGIN.ERRORS.NO_CLIENT"
        case WRONG_CREDENTIALS = "LOGIN.ERRORS.WRONG_CREDENTIALS"
    }

    /// Renders the login view with optional error messaging and custom properties.
    ///
    /// This static method is the central rendering function for login forms throughout
    /// the controller. It loads tenant-specific templates and populates them with
    /// contextual information including error messages, redirect URLs, and branding.
    ///
    /// ## Template Resolution
    ///
    /// The template path is resolved via ``Template/getPath(page:request:)`` which:
    /// 1. Checks for tenant-specific templates first
    /// 2. Falls back to default templates if tenant version not found
    /// 3. Supports multi-tenant customization of login UI
    ///
    /// ## Error Handling
    ///
    /// Errors are passed as translation keys (see ``FrontendErrors``) which are
    /// resolved by the template engine based on the tenant's configured language.
    ///
    /// ## Usage Scenarios
    ///
    /// - Initial login form display (no error)
    /// - Failed authentication attempts (with WRONG_CREDENTIALS error)
    /// - Invalid form submissions (with FORM_NOT_PARSEABLE error)
    /// - System errors (with CONSTRUCT_DATE_ERROR, etc.)
    ///
    /// - Parameters:
    ///   - req: The current HTTP request providing context and client info.
    ///   - status: HTTP status code to return (typically `.ok` or `.forbidden`).
    ///   - error: Optional error code to display on the form. If provided, the
    ///            corresponding translation will be shown to the user.
    ///   - pageProperties: Optional custom page properties. If `nil`, default properties
    ///                     are constructed from the request's client info.
    /// - Returns: A rendered `Response` with the login form HTML and specified status code.
    /// - Throws: `Abort(.badRequest)` if clientInfo is missing, or template rendering errors.
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
                     """, requestId: req.id)
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

    /// Registers login routes with the application.
    ///
    /// - Parameter routes: The routes builder to register endpoints with.
    /// - Throws: Routing configuration errors.
    func boot(routes: RoutesBuilder) throws {
        let login = routes.grouped("login")
        login.get(use: { @Sendable (req: Request) async throws -> Response in
            try await self.getLoginMask(req: req)
        })
        login.post(use: { @Sendable (req: Request) async throws -> Response in
            try await self.doLogin(req: req)
        })
    }

    // MARK: - Route

    /// Displays the tenant-specific or default login form.
    ///
    /// This method handles GET requests to `/login` and renders the appropriate
    /// login form based on the tenant configuration. It supports silent login
    /// (auto-redirect if already authenticated) and tenant-specific branding.
    ///
    /// ## Query Parameters
    ///
    /// - **for**: (Optional) The redirect URI where the user should be sent after
    ///   successful login. If omitted, redirects to the service URL.
    /// - **mode**: (Optional) Login mode (`oauth` or `interceptor`). Derived from
    ///   client info if not explicitly provided.
    ///
    /// ## Silent Login Behavior
    ///
    /// If the user already has a valid, non-expired token AND the tenant has
    /// `silent_login` enabled, this method immediately redirects to the target
    /// URL without showing the login form.
    ///
    /// ## Example
    ///
    /// ```
    /// GET /login?for=https://app.example.com/dashboard&mode=oauth
    /// -> Renders login form with tenant branding
    ///
    /// GET /login?for=https://app.example.com/dashboard (with valid token + silent_login)
    /// -> Immediately redirects to https://app.example.com/dashboard
    /// ```
    ///
    /// - Parameter req: The incoming HTTP request with client info and query parameters.
    /// - Returns: Either a rendered login form `Response` or a redirect `Response`.
    /// - Throws: `Abort(.badRequest)` if clientInfo is missing or invalid.
    @Sendable func getLoginMask(req: Request) async throws -> Response {
        guard let clientInfo = req.clientInfo else {
            Log.error("Client request without clientInfo is not allowed in this context", requestId: req.id)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }
        let requestUri: String? = try req.query.get(at: "for")

        if let payload = clientInfo.validPayload, clientInfo.isExpired() == false {
            if let tenant = clientInfo.tenant, tenant.config.silent_login == true {
                Log.info("User '\(payload.subject.value)' is already logged in.", requestId: req.id)
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

    /// Sets the cookie domain based on client mode and configuration
    ///
    /// - Parameters:
    ///   - cookie: The cookie to modify (passed as inout)
    ///   - clientInfo: Client information containing mode and configuration
    ///   - tenant: The tenant containing interceptor configuration
    ///   - req: The current request
    private func setCookieDomain(
        _ cookie: inout HTTPCookies.Value,
        for clientInfo: ClientInfo,
        tenant: Tenant,
        on req: Request
    ) {
        if clientInfo.mode == .interceptor {
            cookie.domain = tenant.config.interceptor?.cookieOrDomain
                ?? req.forwardInfo?.location.host
                ?? Constants.PUBLIC_DOMAIN
        } else {
            cookie.domain = req.forwardInfo?.location.host ?? req.headers.first(name: "host") ?? Constants.PUBLIC_DOMAIN
        }
        Log.debug("Set cookie to domain: \(cookie.domain ?? "-")", requestId: req.id)
    }

    /// Initiate a login provider
    ///
    /// - Parameters:
    ///   - tenant: the current tenant
    ///   - form: a filled login form
    /// - Returns: a Provider
    /// - Throws: an error if the provider can't be constructed
    private func userLoginProvider(for tenant: Tenant, login form: LoginForm) async throws -> JavaScriptProvider {
        let providerInterpreter = JavaScriptProvider()
        try await providerInterpreter.loadProvider(script: tenant.config.providers.joined(separator: "\n"))
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
            Log.error("Call canNotLoginResponse without clientInfo is not allowed in this context", requestId: req.id)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        Log.info(
            "Cannot log in user \(login.username) to \(req.forwardInfo?.location.description ?? "-")",
            requestId: req.id
        )

        // Record login failure event (Prometheus metrics + entity status update)
        await req.application.authEventActor.recordLoginFailure(
            tenant: clientInfo.tenant?.name,
            client: clientInfo.client,
            mode: clientInfo.mode.rawValue,
            host: req.forwardInfo?.location.host ?? "unknown"
        )

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
            Log.error("Client request without clientInfo is not allowed in this context", requestId: request.id)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        // if interceptor pass early - we allow every redirect
        if clientInfo.mode == .interceptor {
            Log.debug("Check redirect for interceptor:\(redirect.redirect_uri)", requestId: request.id)
            return
        }
        // if redirect points to server url pass early - we allow redirects to ourself, eg /authorise
        if let origin = request.headers.first(name: "Origin") {
            Log.info("Check if redirect is on same domain: \(origin)", requestId: request.id)
            if redirect.redirect_uri.absoluteString.starts(with: origin) {
                Log.info("Pass redirect check, because request is on same domain", requestId: request.id)
                return
            }
        }

        // if oauth
        // check client is there
        guard let client = clientInfo.client else {
            Log.error("No client was detected for login.", requestId: request.id)
            throw Abort(.badRequest, reason: "ERRORS.NO_CLIENT")
        }
        Log.debug("Check redirect for oauth: \(redirect.redirect_uri) on client: \(client.name)", requestId: request.id)

        do {
            try client.checkedRedirect(for: redirect)
        } catch {
            Log.error("""
                      Redirect to \(redirect.redirect_uri) is not allowed
                      on client \(client.name) [\(clientInfo.tenant?.name ?? "-")]
                      """, requestId: request.id)
            throw Abort(.forbidden, reason: "ERRORS.REDIRECT_MISMATCH")
        }
    }

    /// Returns a target location to redirect.
    ///
    /// - Parameters:
    ///   - locationUrl: URL of the location
    ///   - queryItem: The query item that should append to the location
    private func getRedirectTargetLocation(locationUrl: URL, queryItem: URLQueryItem ) -> String {
        return locationUrl.path.starts(with: "/authorize") == true
            ? locationUrl.appending(queryItems: [queryItem]).absoluteString
            : locationUrl.absoluteString
    }

    /// Constructs the issuer URL and audience from request context.
    ///
    /// Determines the issuer (authorization server URL) and audience (client_id) for JWT tokens
    /// by examining request headers and client information. This helper supports both proxied
    /// and direct requests.
    ///
    /// ## Issuer Construction
    ///
    /// The issuer URL is built by:
    /// 1. Checking `X-Forwarded-Proto` header (if behind a proxy)
    /// 2. Falling back to `Constants.TOKEN.isSecure` (https vs http)
    /// 3. Checking `X-Forwarded-Host` header (if behind a proxy)
    /// 4. Falling back to `Host` header
    /// 5. Using tenant's configured hosts as fallback
    /// 6. Finally using `Constants.PUBLIC_DOMAIN` as last resort
    ///
    /// ## Audience Determination
    ///
    /// The audience is the OAuth2 client_id from the client configuration,
    /// or "unknown" if not available.
    ///
    /// - Parameters:
    ///   - req: The incoming HTTP request
    ///   - tenant: The tenant for this authentication request
    ///   - clientInfo: Client information from the request context
    /// - Returns: A tuple containing (issuer: String, audience: String)
    private func constructIssuerAndAudience(
        from req: Request,
        tenant: Tenant,
        clientInfo: ClientInfo
    ) -> (issuer: String, audience: String) {
        let scheme = req.headers.first(name: "X-Forwarded-Proto")
            ?? (Constants.TOKEN.isSecure ? "https" : "http")
        let host = req.headers.first(name: "X-Forwarded-Host")
            ?? req.headers.first(name: "Host")
            ?? tenant.config.hosts.first
            ?? Constants.PUBLIC_DOMAIN
        let issuer = "\(scheme)://\(host)"
        let audience = clientInfo.client?.config.ident.uuidString ?? "unknown"
        return (issuer, audience)
    }

    /// Processes login credentials and authenticates the user.
    ///
    /// This method handles POST requests to `/login`, validating submitted credentials
    /// through the tenant's JavaScript provider, generating JWT tokens upon success,
    /// and setting secure cookies for session management.
    ///
    /// ## Authentication Process
    ///
    /// 1. Decode and validate the login form data
    /// 2. Verify the redirect URI is allowed for the client
    /// 3. Create a login session and store it
    /// 4. Execute the tenant's JavaScript provider to validate credentials
    /// 5. Retrieve user profile and role information from the provider
    /// 6. Generate a JWT token with user claims
    /// 7. Set a secure cookie with proper domain scoping
    /// 8. Redirect to the target URL with login session ID
    ///
    /// ## Security Measures
    ///
    /// - Redirect URI validation against client whitelist
    /// - Credentials validated through tenant-specific provider logic
    /// - Metrics tracking for login attempts, successes, and failures
    /// - Audit logging for successful authentications
    /// - Secure cookie attributes (HttpOnly, domain-scoped)
    ///
    /// ## Cookie Domain Logic
    ///
    /// - **Interceptor mode**: Uses tenant's configured interceptor cookie domain
    /// - **OAuth mode**: Uses the forward host or request host header
    /// - Falls back to `Constants.PUBLIC_DOMAIN` if unable to determine
    ///
    /// ## Error Handling
    ///
    /// Returns login form with error on:
    /// - Invalid form data (FORM_NOT_PARSEABLE)
    /// - Failed authentication (WRONG_CREDENTIALS)
    /// - Date calculation errors (CONSTRUCT_DATE_ERROR)
    ///
    /// - Parameter req: The incoming HTTP request with form data and client context.
    /// - Returns: A redirect `Response` to the target URL with authentication cookie set.
    /// - Throws: `Abort` errors for validation failures or system errors.
    @Sendable func doLogin(req: Request) async throws -> Response {
        guard let clientInfo = req.clientInfo else {
            Log.error("Client request without clientInfo is not allowed in this context", requestId: req.id)
            throw Abort(.badRequest, reason: "ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        guard let tenant = clientInfo.tenant else {
            throw Abort(.badRequest, reason: "ERRORS.MISSING_TENANT")
        }

        // user has to send a correct login form
        guard let loginForm = try? req.content.decode(LoginForm.self) else {
            return try await LoginController.renderLoginView(on: req, status: .badRequest, error: .FORM_NOT_PARSEABLE)
        }
        Log.info("Attempting login \(loginForm.username)", requestId: req.id)

        Prometheus.main.loginAttempts?.observe(1, .init([
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
        Log.info("CONTROLLER: About to call push() with loginId: \(loginSession.loginId.uuidString)", requestId: req.id)
        do {
            try await req.application.authCodeStorage?.push(loginId: loginSession)
            let loginUuid = loginSession.loginId.uuidString
            Log.info("CONTROLLER: push() completed successfully for loginId: \(loginUuid)", requestId: req.id)
        } catch {
            let loginUuid = loginSession.loginId.uuidString
            Log.error(
                "CONTROLLER: push() FAILED - Cannot save login ID: \(loginUuid) - Error: \(error)",
                requestId: req.id
            )
        }

        let redirectTargetLocation = getRedirectTargetLocation(
            locationUrl: redirectLocationUrl,
            queryItem: URLQueryItem(name: "loginid", value: loginSession.loginId.uuidString) )

        // use a provider to check login requests
        let providerInterpreter = try await userLoginProvider(for: tenant, login: loginForm)

        // Ask the provider if the user can login
        if await providerInterpreter.canLogin() == false {
            return try await canNotLoginResponse(on: req, form: loginForm)
        }

        // get the committed subject
        let providedSubject: SubjectProtocol = await providerInterpreter.getSubject(loginHandle: loginForm.username)

        // get users profile from provider
        let profile: CodableProfile? = await providerInterpreter.getProfile()
        if profile == nil {
            Log.error("Cannot get profile of \(loginForm.username)", requestId: req.id)
        }

        // get users role from provider
        let role = await providerInterpreter.getRole()

        // scopes
        let scopes = loginForm.scope?.split(separator: "+").map({String($0)}) ?? []
        let possipleProviderScopes = await providerInterpreter.getScopes()

        // filtering providerScopes
        let providerScopes = if let client = clientInfo.client {
            allowedScopes(on: client.config.allowedProviderScopes ?? [], for: possipleProviderScopes)
        } else { [] as [String]}
        
        let finalScopes = Array(Set(scopes + providerScopes)).joined(separator: " ")
        
        
        // create jwt
        guard let expirationDate = getExpirationDate() else {
            return try await LoginController.renderLoginView(
                on: req,
                status: .internalServerError,
                error: .CONSTRUCT_DATE_ERROR
            )
        }
        let responsibleDomainHash = ResponsibilityDomain.getResponsibilityDomain(on: req, for: clientInfo)

        // Construct issuer and audience for JWT claims
        let (issuer, audience) = constructIssuerAndAudience(from: req, tenant: tenant, clientInfo: clientInfo)

        // Create current timestamp for iat and auth_time
        let now = Date()

        let payload = Payload(
            issuer: IssuerClaim(value: issuer),
            subject: providedSubject.subject,
            audience: AudienceClaim(value: audience),
            expiration: ExpirationClaim(value: expirationDate),
            issuedAt: IssuedAtClaim(value: now),
            authTime: AuthTimeClaim(value: now),
            tenant: tenant.name,
            responsibility: responsibleDomainHash.hash,
            role: role,
            user: loginForm.username,
            scope: finalScopes,
            profile: profile
        )
        let token = try await req.jwt.sign(payload)

        Log.info("Redirect to \(redirectTargetLocation)", requestId: req.id)
        let response = req.redirect(to: redirectTargetLocation, redirectType: .normal)

        // set the cookie only for the request domain!
        var cookie = HTTPCookies.Value.defaultCookie(expires: expirationDate, withContent: token)
        setCookieDomain(&cookie, for: clientInfo, tenant: tenant, on: req)
        response.cookies[Constants.COOKIE.NAME] = cookie

        // Success!
        Log.info("""
                 Login succeeded \(loginForm.username)
                 to \(req.forwardInfo?.location.host ?? "//")\(req.forwardInfo?.location.path ?? "/")
                 """,
                 requestId: req.id
        )
        Log.audit.info("\(providedSubject.subject) on \(cookie.domain ?? "-")")

        // For interceptor mode, create a session entry to track active users
        // (OAuth mode creates refresh tokens separately in TokenController)
        if clientInfo.mode == .interceptor {
            Log.info("Creating session entry for interceptor login: \(tenant.name)")
            let sessionCode = Code()
            let interceptorSession = AuthSession(
                type: .refresh,
                state: "interceptor-login",
                code: sessionCode,
                scopes: [],
                payload: payload,
                redirect: "",
                ttl: Int64(Constants.COOKIE.EXPIRATION_DAYS * 24 * 60 * 60)
            )
            try? await req.application.authCodeStorage?.set(authSession: interceptorSession)
        }

        // Record login success event (Prometheus metrics + entity status update)
        await req.application.authEventActor.recordLoginSuccess(
            tenant: tenant.name,
            client: clientInfo.client,
            mode: clientInfo.mode.rawValue,
            host: req.forwardInfo?.location.host ?? "unknown"
        )

        return response
    }
}
