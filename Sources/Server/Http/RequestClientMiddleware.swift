import Foundation
import Vapor
import CryptoSwift

final class RequestClientMiddleware: AsyncMiddleware {

    enum RequestClientMiddlewareError: Error {
        case noClient
    }

    /// Implement a vapor middleware to set client information to the request
    ///
    /// - Parameters:
    ///   - request: The current request
    ///   - next: Responder next in chain
    /// - Returns: A future response
    ///
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // we dp not need a clientInfo for some requests
        if ["/health", "/health/ready", "/metrics", "/versions"].contains(request.url.string) {
            return try await next.respond(to: request)
        }

        // If we are in Interceptor mode, a header is set and nothing else matches.
        let loginMode: LoginMode = getLoginMode(on: request)
        Log.info("Login Mode: \(loginMode.rawValue) to: \(request.url.string)", request: request)

        // token request does not need further checks and do not have a clientInfo, yet
        if ["/token", "/token/info"].contains(request.url.string) {
            return try await next.respond(to: request)
        }

        var clientInfo = getLoginClientInfo(on: request)

        let payload = try? request.jwt.verify(as: Payload.self)
        if let payload {
            Log.debug("Enrich clientInfo on request with payload.", request: request)
            clientInfo = try enrichClientInfo(on: request, with: payload, info: clientInfo)
        } else { // Only when the user did not have a token
            Log.debug("Enrich clientInfo on request without payload.", request: request)
            clientInfo = try enrichClientInfo(on: request, info: clientInfo)
        }

        // Responsibility check
        request.responsibilityDomain = ResponsibilityDomain.getResponsibilityDomain(on: request, for: clientInfo)
        if let responsibility = clientInfo.validPayload?.responsibility,
           responsibility != request.responsibilityDomain?.hash {
            Log.info("Not responsible for this domain \(clientInfo.responsibleDomain)", request: request)
            clientInfo.validPayload = nil
        }
        request.clientInfo = clientInfo

        return try await next.respond(to: request)
    }

    // MARK: - Private functions

    /// Get the current `LoginMode`
    ///
    /// - Parameter request: The current `Request`
    /// - Returns: The `LoginMode` that can be .interceptor or .oauth
    private func getLoginMode(on request: Request) -> LoginMode {
        LoginMode(
                rawValue: request.headers.first(name: "X-Uitsmijter-Mode")          // 1. set by header
                        ?? (try? request.query.get(at: "mode"))                     // 2. if not: set by query parameter
                        ??
                        (
                                request.url.string == "/interceptor" ? "interceptor" : "oauth"
                        )                                                           // 3. special route, or def
        ) ?? .oauth                                                                 // 4. ensure default
    }

    /// Get the `ClientInfo` constructed from a `Request`
    ///
    /// - Parameter request: The current `Request`
    /// - Returns: a ClientInfo with mode, `ClientInfoRequest`, referer and serviceUrl
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

    /// If a payload is given this function returns a new payload with data of
    /// - Token `expired`
    /// - Tokens `validPayload`
    /// - `tenant`
    /// - Tokens `subject`
    ///
    /// - Parameter:
    ///     - request: The users Request
    ///     - payload: The users `Payload`
    ///     - ClientInfo: the current ClientInfo
    /// - Returns: A `ClientInfo` with enriched Data
    /// - Throws: An error when something Tenant is unknown or the Tenant does not match.
    private func enrichClientInfo(
            on request: Request,
            with payload: Payload,
            info originalClient: ClientInfo
    ) throws -> ClientInfo {
        Log.info("enrichClientInfo with payload: payload tenant \(payload.tenant)", request: request)

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
                    , request: request)
        }

        // Get Client - when presented // Refactoring 1.x: Use clientParser | UIT-399
        if let clientId = try? getClientId(on: request) {
            Log.debug("Found client_id: \(clientId) in login prerequisite", request: request)
            guard let client = Client.find(id: clientId) else {
                Log.error("Can not find client with id \(clientId)", request: request)
                throw Abort(.badRequest, reason: "LOGIN.ERRORS.NO_CLIENT")
            }
            clientInfo.client = client
        }

        // Get Tenant
        if let tenant = clientInfo.client?.config.tenant {
            clientInfo.tenant = tenant
        } else {
            clientInfo.tenant = try getTenant(on: payload)
        }

        // Check Tenant belongs to Client
        if clientInfo.client != nil && clientInfo.client?.config.tenant?.ref != clientInfo.tenant?.ref {
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
                    request: request
            )
            try checkTenantMatch(tenant: tenant, for: clientInfo.responsibleDomain, user: payload.user)
        }

        // get User Subject
        clientInfo.subject = payload.subject.value
        return clientInfo
    }

    /// If a payload is not present (not logged in) this function returns a new clientInfo with data of
    /// - `Client`
    /// - `Tenant`
    ///
    /// - Parameter
    ///      - request: The users request
    ///      - clientInfo: The current `ClientInfo`
    /// - Returns: A `ClientInfo` with enriched Data
    /// - Throws: An error when the form is invalid, or the client can't be found
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
                Log.debug("Found client_id: \(clientId) in login prerequisite", request: request)
                guard let client = Client.find(id: clientId) else {
                    Log.error("Can not find client with id \(clientId)", request: request)
                    throw Abort(.badRequest, reason: "LOGIN.ERRORS.NO_CLIENT")
                }
                // add login, we can set the client
                clientInfo.client = client
                clientInfo.tenant = client.config.tenant ?? Tenant.find(forHost: loginForHost)
                Log.info("""
                         Login prerequisite
                         with client: \(client.name)
                         for tenant [\(clientInfo.tenant?.name ?? "-")]
                         """, request: request)
            } else {
                // try to find the Tenant without a client (Interceptor)
                Log.info("""
                         No client was presented. Try to find tenant based on host: \(loginForHost)")
                         """, request: request)
                clientInfo.tenant = Tenant.find(forHost: loginForHost)
            }
            // Login forward to host
            request.forwardInfo = ForwardInfo(location: loginForLocation)
        } else {
            if let clientId = try? getClientId(on: request) {
                Log.debug("Found client_id: \(clientId) in login prerequisite", request: request)
                guard let client = Client.find(id: clientId) else {
                    throw Abort(.badRequest, reason: "LOGIN.ERRORS.NO_CLIENT")
                }
                clientInfo.client = client
                clientInfo.tenant = client.config.tenant
            } else {
                // get the tenant from the requested host
                Log.info("""
                         No client was presented.
                         Try to find tenant based on requested host: \(clientInfo.responsibleDomain)")
                         """, request: request)
                clientInfo.tenant = try getTenant(for: clientInfo.responsibleDomain)
            }
        }
        return clientInfo
    }

    /// Get the URL and the host string back from a location string
    ///
    /// - Parameter
    ///     - info: the ClientInfo from the request
    ///     - location: A location String
    /// - Returns: A tuple of (url: URL, host: String)
    /// - Throws: A `.preconditionFailed` error if the `location` can not be an URL
    func getLoginLocation(with info: ClientInfo, from location: String) throws -> (URL, String) {
        Log.info("Try to find location: \(location)")

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
    /// - Parameter payload: `Payload` from a valid `JWT`
    /// - Returns: A `Tenant` that matches the host
    /// - Throws: A `.badRequest` error if the tenant is not found
    private func getTenant(on payload: Payload) throws -> Tenant {
        guard let tenant = Tenant.find(name: payload.tenant) else {
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
    /// - Parameter requestedHost: String of the host
    /// - Returns: A `Tenant` that matches the host
    /// - Throws: A `.badRequest` error if the tenant is not found
    private func getTenant(for requestedHost: String) throws -> Tenant {
        guard let tenant = Tenant.find(forHost: requestedHost) else {
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
    ///   - user: Optional user for logging
    /// - Throws: An .forbidden error if the tenant mismatch
    private func checkTenantMatch(tenant: Tenant, for host: String, user: String? = nil) throws {
        let requestedTenant = try getTenant(for: host)
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
            Log.info("Can not find a client in header, parameter or location", request: request)
            throw RequestClientMiddlewareError.noClient
        }
        return client_id
    }
}
