import Foundation
import Vapor
import CryptoSwift
import Logger

// MARK: - Request Client Middleware

/// Middleware that enriches incoming requests with client and tenant information.
///
/// This middleware is a critical component in the authentication pipeline that extracts
/// and validates client, tenant, and user information from incoming requests. It handles
/// both OAuth and Interceptor login modes, validates JWT tokens, and ensures proper
/// tenant-client associations.
///
/// ## Processing Flow
///
/// 1. Determines the login mode (OAuth or Interceptor)
/// 2. Extracts client information from headers, query parameters, or request body
/// 3. Validates JWT tokens if present
/// 4. Enriches request with client, tenant, and user information
/// 5. Performs responsibility domain checks
///
/// ## Login Modes
///
/// - **OAuth Mode**: Standard OAuth2 authorization code flow
/// - **Interceptor Mode**: Traefik ForwardAuth middleware integration
///
/// ## Security Considerations
///
/// - Validates tenant-client associations
/// - Checks JWT token expiration
/// - Verifies responsibility domain matches
/// - Ensures redirect URIs are allowed
///
/// ## Example Usage
///
/// ```swift
/// // In configure.swift
/// app.middleware.use(RequestClientMiddleware())
/// ```
///
/// ## Topics
///
/// ### Middleware Response
/// - ``respond(to:chainingTo:)``
///
/// ### Error Handling
/// - ``RequestClientMiddlewareError``
///
/// - SeeAlso: ``ClientInfo``
/// - SeeAlso: ``LoginMode``
/// - SeeAlso: ``RequestClientParser``
final class RequestClientMiddleware: AsyncMiddleware {

    // MARK: - Error Types

    /// Errors that can occur during request client parsing.
    enum RequestClientMiddlewareError: Error {
        /// No client information could be found in the request
        case noClient
    }

    // MARK: - Middleware Implementation

    /// Processes incoming requests and enriches them with client and tenant information.
    ///
    /// This method is called for every request that passes through the middleware chain.
    /// It extracts client information, validates tokens, and ensures proper tenant-client
    /// associations before passing the request to the next responder.
    ///
    /// ## Bypassed Routes
    ///
    /// The following routes skip client enrichment for performance:
    /// - `/health`
    /// - `/health/ready`
    /// - `/metrics`
    /// - `/versions`
    /// - `/token`
    /// - `/token/info`
    ///
    /// ## Request Enrichment
    ///
    /// The middleware adds the following to the request:
    /// - ``ClientInfo`` with mode, tenant, client, and user information
    /// - ``ResponsibilityDomain`` for multi-tenant validation
    /// - JWT payload validation and expiration status
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - next: The next responder in the middleware chain
    /// - Returns: An HTTP response from the chain
    /// - Throws:
    ///   - `Abort(.badRequest)` if client or tenant information is invalid
    ///   - `Abort(.forbidden)` if tenant mismatch occurs
    ///   - `Abort(.notAcceptable)` if client-tenant association is invalid
    ///
    /// - SeeAlso: ``ClientInfo``
    /// - SeeAlso: ``getLoginMode(on:)``
    /// - SeeAlso: ``enrichClientInfo(on:with:info:)``
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // we dp not need a clientInfo for some requests
        if ["/health", "/health/ready", "/metrics", "/versions"].contains(request.url.string) {
            return try await next.respond(to: request)
        }

        // If we are in Interceptor mode, a header is set and nothing else matches.
        let loginMode: LoginMode = getLoginMode(on: request)
        Log.info("Login Mode: \(loginMode.rawValue) to: \(request.url.string)", requestId: request.id)

        // token request does not need further checks and do not have a clientInfo, yet
        if ["/token", "/token/info"].contains(request.url.string) {
            return try await next.respond(to: request)
        }

        var clientInfo = getLoginClientInfo(on: request)

        let payload = try? request.jwt.verify(as: Payload.self)
        if let payload {
            Log.debug("Enrich clientInfo on request with payload.", requestId: request.id)
            clientInfo = try await enrichClientInfo(on: request, with: payload, info: clientInfo)
        } else { // Only when the user did not have a token
            Log.debug("Enrich clientInfo on request without payload.", requestId: request.id)
            clientInfo = try await enrichClientInfo(on: request, info: clientInfo)
        }

        // Responsibility check
        request.responsibilityDomain = ResponsibilityDomain.getResponsibilityDomain(on: request, for: clientInfo)
        if let responsibility = clientInfo.validPayload?.responsibility,
           responsibility != request.responsibilityDomain?.hash {
            Log.info("Not responsible for this domain \(clientInfo.responsibleDomain)", requestId: request.id)
            clientInfo.validPayload = nil
        }
        request.clientInfo = clientInfo

        return try await next.respond(to: request)
    }

    // MARK: - Private Helper Methods

    /// Determines the login mode from the request.
    ///
    /// The login mode can be either OAuth or Interceptor, and it's critical to distinguish
    /// between them as they have different security and processing requirements.
    ///
    /// ## Detection Order
    ///
    /// The login mode is determined by checking the following sources in order:
    /// 1. `X-Uitsmijter-Mode` HTTP header
    /// 2. `mode` query parameter
    /// 3. `mode` in request body
    /// 4. Special route detection (`/interceptor`)
    /// 5. Default to OAuth mode
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Header-based mode
    /// // X-Uitsmijter-Mode: interceptor
    ///
    /// // Query parameter mode
    /// // /authorize?mode=oauth&client_id=...
    ///
    /// // Route-based mode
    /// // GET /interceptor
    /// ```
    ///
    /// - Parameter request: The incoming HTTP request
    /// - Returns: The detected ``LoginMode`` (defaults to `.oauth`)
    ///
    /// - SeeAlso: ``LoginMode``
    private func getLoginMode(on request: Request) -> LoginMode {
        LoginMode(
            rawValue: request.headers.first(name: "X-Uitsmijter-Mode")          // 1. set by header
                ?? (try? request.query.get(at: "mode"))                             // 2. if not: set by query parameter
                ?? ( try? request.content.get(at: "mode"))                          // 3. if not: get by content object
                ??
                (
                    request.url.string == "/interceptor" ? "interceptor" : "oauth"
                )                                                                   // 4. special route, or def
        ) ?? .oauth                                                                 // 5. ensure default
    }

    /// Constructs initial client information from the request.
    ///
    /// This method extracts and assembles client information from various sources in the
    /// request including headers, query parameters, and request body. It handles the
    /// complexity of determining the responsible domain for both OAuth and Interceptor modes.
    ///
    /// ## Extracted Information
    ///
    /// - HTTP scheme (from `X-Forwarded-Proto` header or defaults)
    /// - Host (from multiple potential sources, checked in priority order)
    /// - URI (from `X-Forwarded-Uri` header)
    /// - Referer (from `referer` header)
    /// - Responsible domain (mode-dependent logic)
    ///
    /// ## Host Resolution Order
    ///
    /// 1. `for` query parameter
    /// 2. `redirect_uri` from location content
    /// 3. `redirect_uri` query parameter
    /// 4. `location` query parameter
    /// 5. `X-Forwarded-Host` header
    /// 6. `PUBLIC_DOMAIN` environment variable
    ///
    /// - Parameter request: The incoming HTTP request
    /// - Returns: A partially populated ``ClientInfo`` structure
    ///
    /// - SeeAlso: ``ClientInfo``
    /// - SeeAlso: ``ClientInfoRequest``
    /// - SeeAlso: ``LocationContent``
    private func getLoginClientInfo(on request: Request) -> ClientInfo {
        // get the login mode
        let loginMode: LoginMode = getLoginMode(on: request)

        // Gather info about the request
        let httpScheme: String = request.headers.first(
            name: "X-Forwarded-Proto"
        ) ?? (Constants.TOKEN.isSecure ? "https" : "http")

        // Request chain of the responsible httpHost
        let locationContent = try? request.content.decode(LocationContent.self)
        let redirect_uri = try? locationContent?.location.groups(regex: "redirect_uri=([^&\"]+)")[1]

        let httpHost: String = (try? URL(string: request.query.get(at: "for"))?.host)
            ?? (URL(string: redirect_uri ?? "")?.host)
            ?? (URL(string: redirect_uri?.removingPercentEncoding ?? "")?.host)
            ?? (try? URL(string: request.query.get(at: "redirect_uri"))?.host)
            ?? (try? URL(string: request.query.get(at: "location"))?.host) // ToDo: rename for to location
            ?? request.headers.first(name: "X-Forwarded-Host")
            ?? (URL(string: Constants.PUBLIC_DOMAIN)?.host ?? "localhost")

        let httpUri = request.headers.first(name: "X-Forwarded-Uri") ?? "/"
        let referer = request.headers.first(name: "referer")

        // besides the httpHost we need the definite domain for uitsmijter is interacting for.
        // when oauth this is always the httpHost
        // when interceptor it depends on the state of the requests.
        let domain =
            (loginMode == .oauth ? httpHost : nil)
            ?? (loginMode == .interceptor && request.url.path == "/logout"
                    ? URL(string: referer ?? "")?.host
                    : nil)
            ?? locationContent?.url?.host
            ?? httpHost

        // Construct the client info
        return ClientInfo(
            mode: loginMode,
            requested: ClientInfoRequest(
                scheme: httpScheme,
                host: httpHost,
                uri: httpUri
            ),
            referer: referer,
            responsibleDomain: domain,
            serviceUrl: (request.headers["host"].first ?? Constants.PUBLIC_DOMAIN)
        )
    }

    /// Enriches client information when a valid JWT payload is present.
    ///
    /// This method is called when the user has a JWT token (logged in state). It validates
    /// the token, checks expiration, resolves the tenant and client, and ensures proper
    /// tenant-client associations.
    ///
    /// ## Enrichment Process
    ///
    /// 1. Validates JWT expiration
    /// 2. Resolves client from `client_id` if present
    /// 3. Resolves tenant from client or JWT payload
    /// 4. Validates tenant-client association
    /// 5. Checks tenant responsibility for the requested domain
    /// 6. Extracts user subject from payload
    ///
    /// ## Security Checks
    ///
    /// - Verifies JWT is not expired
    /// - Ensures client and tenant association is valid
    /// - Confirms tenant matches the requested domain
    /// - Validates tenant responsibility (except for localhost)
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - payload: The validated JWT ``Payload``
    ///   - originalClient: The initial ``ClientInfo`` structure
    /// - Returns: An enriched ``ClientInfo`` with tenant, client, and user information
    /// - Throws:
    ///   - `Abort(.badRequest)` if client or tenant cannot be found
    ///   - `Abort(.notAcceptable)` if tenant-client mismatch occurs
    ///   - `Abort(.forbidden)` if tenant doesn't match the requested domain
    ///
    /// - SeeAlso: ``Payload``
    /// - SeeAlso: ``ClientInfo``
    /// - SeeAlso: ``checkTenantMatch(tenant:for:request:user:)``
    @MainActor
    private func enrichClientInfo(
        on request: Request,
        with payload: Payload,
        info originalClient: ClientInfo
    ) throws -> ClientInfo {
        Log.info("enrichClientInfo with payload: payload tenant \(payload.tenant)", requestId: request.id)

        var clientInfo = originalClient

        // Check expiration
        do {
            try payload.expiration.verifyNotExpired(currentDate: Date())
            clientInfo.expired = false
            clientInfo.validPayload = payload
        } catch {
            clientInfo.expired = true
            Log.notice("""
                       User \(payload.user) on tenant \(payload.tenant) has expired token.
                       Tenant will be used for further processing.
                       """
                       , requestId: request.id)
        }

        // Get Client - when presented // Refactoring 1.x: Use clientParser | UIT-399
        if let clientId = try? getClientId(on: request) {
            Log.debug("Found client_id: \(clientId) in login prerequisite", requestId: request.id)
            guard let client = Client.find(in: request.application.entityStorage, clientId: clientId) else {
                Log.error("Cannot find client with id \(clientId)", requestId: request.id)
                throw Abort(.badRequest, reason: "LOGIN.ERRORS.NO_CLIENT")
            }
            clientInfo.client = client
        }

        // Get Tenant
        if let tenant = clientInfo.client?.config.tenant(in: request.application.entityStorage) {
            clientInfo.tenant = tenant
        } else {
            clientInfo.tenant = try getTenant(on: payload, request: request)
        }

        // Check Tenant belongs to Client
        if clientInfo.client != nil &&
            clientInfo.client?.config.tenant(in: request.application.entityStorage)?.ref != clientInfo.tenant?.ref {
            throw Abort(.notAcceptable, reason: "LOGIN.ERRORS.TENANT_MISMATCH")
        }

        // Check if the requested tenant matches the JWT tenant
        // except for localhost-tests.
        guard let tenant = clientInfo.tenant else {
            throw Abort(.badRequest, reason: "ERRORS.NO_TENANT")
        }

        if request.url.path.contains("/logout") == false && clientInfo.requested.host != "localhost" {
            Log.info(
                "Check responsibleDomain for tenant \(tenant.name) for domain \(clientInfo.responsibleDomain)",
                requestId: request.id
            )
            try checkTenantMatch(
                tenant: tenant, for: clientInfo.responsibleDomain, request: request, user: payload.user
            )
        }

        // get User Subject
        clientInfo.subject = payload.subject.value
        return clientInfo
    }

    /// Enriches client information when no JWT payload is present (unauthenticated user).
    ///
    /// This method is called when the user is not logged in. It resolves the client and
    /// tenant from request parameters, with special handling for the POST /login route
    /// which requires extracting information from the login form.
    ///
    /// ## Resolution Logic
    ///
    /// ### For POST /login Requests
    /// 1. Extracts `location` from login form
    /// 2. Resolves client from `client_id` if present
    /// 3. Determines tenant from client or host in location
    /// 4. Sets forward location for post-login redirect
    ///
    /// ### For Other Requests
    /// 1. Resolves client from `client_id` if present
    /// 2. Determines tenant from client or requested host
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Login form with location
    /// // POST /login
    /// // location=https://app.example.com/callback?client_id=...
    ///
    /// // OAuth authorize without login
    /// // GET /authorize?client_id=abc123&redirect_uri=...
    /// ```
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - originalClient: The initial ``ClientInfo`` structure
    /// - Returns: An enriched ``ClientInfo`` with client and tenant information
    /// - Throws:
    ///   - `Abort(.badRequest)` if login form is invalid or client cannot be found
    ///   - `Abort(.preconditionFailed)` if location cannot be parsed
    ///
    /// - SeeAlso: ``ClientInfo``
    /// - SeeAlso: ``LoginForm``
    /// - SeeAlso: ``getLoginLocation(with:from:)``
    @MainActor
    private func enrichClientInfo(
        on request: Request,
        info originalClient: ClientInfo
    ) throws -> ClientInfo {
        var clientInfo = originalClient
        // Special Case: POST /login - we need the tenant from the LoginForm forward url
        if request.method == .POST && request.url.path == "/login" {
            // The login form must have a `location` field
            guard let location: String = try? request.content.get(at: "location") else {
                throw Abort(.badRequest, reason: "LOGIN.ERRORS.FORM_NOT_PARSEABLE")
            }
            let (loginForLocation, loginForHost) = try getLoginLocation(with: clientInfo, from: location)
            if let clientId = try? getClientId(on: request) {
                Log.debug("Found client_id: \(clientId) in login prerequisite", requestId: request.id)
                guard let client = Client.find(in: request.application.entityStorage, clientId: clientId) else {
                    Log.error("Cannot find client with id \(clientId)", requestId: request.id)
                    throw Abort(.badRequest, reason: "LOGIN.ERRORS.NO_CLIENT")
                }
                // add login, we can set the client
                clientInfo.client = client
                clientInfo.tenant = client.config.tenant(in: request.application.entityStorage) ??
                    Tenant.find(in: request.application.entityStorage, forHost: loginForHost)
                Log.info("""
                         Login prerequisite
                         with client: \(client.name)
                         for tenant [\(clientInfo.tenant?.name ?? "-")]
                         """, requestId: request.id)
            } else {
                // try to find the Tenant without a client (Interceptor)
                Log.info("""
                         No client was presented. Try to find tenant based on host: \(loginForHost)")
                         """, requestId: request.id)
                clientInfo.tenant = Tenant.find(in: request.application.entityStorage, forHost: loginForHost)
            }
            // Login forward to host
            request.forwardInfo = ForwardInfo(location: loginForLocation)
        } else {
            if let clientId = try? getClientId(on: request) {
                Log.debug("Found client_id: \(clientId) in login prerequisite", requestId: request.id)
                guard let client = Client.find(in: request.application.entityStorage, clientId: clientId) else {
                    throw Abort(.badRequest, reason: "LOGIN.ERRORS.NO_CLIENT")
                }
                clientInfo.client = client
                clientInfo.tenant = client.config.tenant(in: request.application.entityStorage)
            } else {
                // get the tenant from the requested host
                Log.info("""
                         No client was presented.
                         Try to find tenant based on requested host: \(clientInfo.responsibleDomain)")
                         """, requestId: request.id)
                clientInfo.tenant = try getTenant(for: clientInfo.responsibleDomain, request: request)
            }
        }
        return clientInfo
    }

    /// Parses a location string into URL and host components.
    ///
    /// This method handles the complexity of extracting host information from a location
    /// string, which may contain encoded redirect URIs or other nested parameters. It's
    /// primarily used during login processing.
    ///
    /// ## Location Formats
    ///
    /// Supports various formats:
    /// - Direct URL: `https://app.example.com/callback`
    /// - With redirect_uri: `https://auth.example.com?redirect_uri=https%3A%2F%2Fapp.example.com`
    /// - Nested parameters: Complex OAuth authorization URLs
    ///
    /// - Parameters:
    ///   - info: The current ``ClientInfo`` for fallback domain resolution
    ///   - location: The location string to parse
    /// - Returns: A tuple containing the parsed URL and extracted host string
    /// - Throws: `Abort(.preconditionFailed)` if the location cannot be parsed as a valid URL
    ///
    /// - SeeAlso: ``enrichClientInfo(on:info:)``
    func getLoginLocation(with info: ClientInfo, from location: String) throws -> (URL, String) {
        Log.debug("Trying to find location: \(location)")

        let redirectUrl = try? location.groups(regex: "redirect_uri=([^&\"]+)")[1]
        guard
            let loginForLocation: URL = URL(string: location),
            let loginForHost = loginForLocation.host
                ?? (info.responsibleDomain != info.serviceUrl ? URL(string: info.responsibleDomain) : nil)?.host
                ?? URL(string: redirectUrl?.removingPercentEncoding ?? "")?.host
                ?? URL(string: Constants.PUBLIC_DOMAIN)?.host
        else {
            throw Abort(.preconditionFailed, reason: "LOGIN.ERRORS.MISSING_LOCATION")
        }
        Log.info("Login to location, for host: \(loginForLocation), \(loginForHost)")
        return (loginForLocation, loginForHost)
    }

    /// Get the `Tenant` from the requested `Payload`
    ///
    /// - Parameters:
    ///   - payload: `Payload` from a valid `JWT`
    ///   - request: The current request
    /// - Returns: A `Tenant` that matches the host
    /// - Throws: A `.badRequest` error if the tenant is not found
    @MainActor
    private func getTenant(on payload: Payload, request: Request) throws -> Tenant {
        guard let tenant = Tenant.find(in: request.application.entityStorage, name: payload.tenant) else {
            Log.info("No tenant for name \(payload.tenant) found")
            metricsInterceptorFailure?.inc(1, [
                ("requested_tenant", payload.tenant),
                ("reason", "NO_TENANT")
            ])
            throw Abort(.badRequest, reason: "ERRORS.NO_TENANT")
        }
        return tenant
    }

    /// Get the `Tenant` from the requested `Host`
    ///
    /// - Parameters:
    ///   - requestedHost: String of the host
    ///   - request: The current request
    /// - Returns: A `Tenant` that matches the host
    /// - Throws: A `.badRequest` error if the tenant is not found
    @MainActor
    private func getTenant(for requestedHost: String, request: Request) throws -> Tenant {
        guard let tenant = Tenant.find(in: request.application.entityStorage, forHost: requestedHost) else {
            Log.info("No tenant for host \(requestedHost) found")
            metricsInterceptorFailure?.inc(1, [
                ("requested_host", requestedHost),
                ("reason", "NO_TENANT")
            ])
            throw Abort(.badRequest, reason: "ERRORS.NO_TENANT")
        }
        return tenant
    }

    /// Check that the tenant matches the tenant who is responsible for this request
    ///
    /// - Parameters:
    ///   - tenant: The `Tenant` to check on
    ///   - host: the host that is requested
    ///   - request: The current request
    ///   - user: Optional user for logging
    /// - Throws: An .forbidden error if the tenant mismatch
    @MainActor
    private func checkTenantMatch(tenant: Tenant, for host: String, request: Request, user: String? = nil) throws {
        let requestedTenant = try getTenant(for: host, request: request)
        if tenant != requestedTenant {
            Log.info("""
                     Request another tenant than the JWT was signed for.
                     Signed for \(tenant.name)
                     Requested for \(requestedTenant.name)
                     User: \(user ?? "-")
                     """)

            metricsInterceptorFailure?.inc(1, [
                ("requested_host", host),
                ("tenant", tenant.name),
                ("reason", "TENANT_MISMATCH")
            ])
            throw Abort(.forbidden, reason: "ERRORS.TENANT_MISMATCH")
        }
    }

    /// Returns the client_id from the request in the following order:
    /// 1. From the Headers
    /// 2. From the query parameters
    /// 3. From the loginForm location query params
    ///
    /// - Parameter request: The current request
    /// - Returns: the `client_id` the user is requested
    /// - Throws: An error if the client_id is not found in the request headers, the query parameters or the
    ///           form location data
    private func getClientId(on request: Request) throws -> String {
        let contentLocation: String? = try? request.content.get(at: "location")
        guard let client_id = try? request.headers.first(name: "client_id")
                ?? request.query.get(at: "client_id")
                ?? contentLocation?.groups(regex: "client_id=([^&\"]+)")[1]
        else {
            Log.debug("Cannot find a client in header, parameter or location", requestId: request.id)
            throw RequestClientMiddlewareError.noClient
        }
        return client_id
    }
}
