import Vapor
import Foundation
import Logger

struct AuthorizeController: RouteCollection, OAuthControllerProtocol {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("authorize")
        auth.get(use: { @Sendable (req: Request) async throws -> Response in
            try await self.doAuth(req: req)
        })
    }

    /// GET /authorize - Get an authorize code
    /// https://www.oauth.com/oauth2-servers/server-side-apps/authorization-code/
    ///
    /// - Parameter req: Current request
    /// - Returns: A http response to the requesting user
    /// - Throws: An Error if something can not be parsed correctly
    @Sendable func doAuth(req: Request) async throws -> Response {

        let codeChallengeMethod = try getCodeChallengeMethod(on: req)
        let authRequest = try getAuthRequest(on: req, with: codeChallengeMethod)

        // Check if clientInfo is available - if not, render login with 401 instead of throwing 400
        guard let clientInfo = req.clientInfo else {
            Log.error("Request without clientInfo in authorize endpoint", requestId: req.id)
            return try await LoginController.renderLoginView(
                on: req,
                status: .unauthorized,
                error: nil,
                props: PageProperties(
                    title: "Login required",
                    requestUri: req.url.string,
                    tenant: nil
                )
            )
        }

        // PKCE validation must happen BEFORE loginid validation
        // This ensures we return the correct error for PKCE violations
        try await validatePKCERequirement(authRequest: authRequest, on: req)

        let loginIdent = try? req.query.decode(LoginId.self)
        Log.info("CONTROLLER: loginIdent = \(loginIdent?.loginid.uuidString ?? "nil")", requestId: req.id)
        if let loginIdent {
            let loginUuid = loginIdent.loginid.uuidString
            Log.info("CONTROLLER: About to call pull() with loginUuid: \(loginUuid)", requestId: req.id)
            let pullResult = await req.application.authCodeStorage?.pull(loginUuid: loginIdent.loginid)
            Log.info(
                "CONTROLLER: pull() returned: \(String(describing: pullResult)) for loginUuid: \(loginUuid)",
                requestId: req.id
            )
            if pullResult == false {
                Log.error("CONTROLLER: pull() returned FALSE - throwing BADLOGINID error", requestId: req.id)
                throw Abort(.badRequest, reason: "LOGIN.ERRORS.BADLOGINID")
            }
            Log.info("CONTROLLER: pull() SUCCESS - continuing with authorization flow", requestId: req.id)
        }

        if loginIdent == nil && clientInfo.client?.config.referrers?.isNotEmpty ?? false {
            Log.debug("Checking referrers for client \(clientInfo.client?.name ?? "-")", requestId: req.id)
            guard let referer = clientInfo.referer else {
                Log.error("Request comes without referer", requestId: req.id)
                throw Abort(.badRequest, reason: "LOGIN.ERRORS.WRONG_REFERER")
            }
            do {
                try clientInfo.client?.checkedReferer(for: referer)
            } catch ClientError.illegalReferer(let referer, let reason) {
                Log.info(
                    "Cannot authorize because client referer does not match \(referer). \(reason)", requestId: req.id
                )
                throw Abort(.forbidden, reason: reason)
            } catch {
                throw Abort(.badRequest, reason: error.localizedDescription)
            }
        }

        if let silent_login = req.clientInfo?.tenant?.config.silent_login,
           // If request is not from the login form
           loginIdent == nil,
           // Silent login is turned off
           silent_login == false {
            Log.info("Silent login is disabled for tenant \(req.clientInfo?.tenant?.name ?? "-")", requestId: req.id)
            req.clientInfo?.validPayload = nil
        }

        // if not logged in, redirect to login - than proceed
        // if already logged in, than generate a code.
        let payloadStatus = req.clientInfo?.validPayload != nil ? "present" : "nil"
        Log.debug("req.clientInfo?.validPayload = \(payloadStatus)", requestId: req.id)
        Log.debug("req.clientInfo?.expired = \(req.clientInfo?.expired ?? false)", requestId: req.id)
        guard let userPayload = req.clientInfo?.validPayload else {
            Log.info("No valid token, render login", requestId: req.id)

            let url = "\(clientInfo.requested.scheme)://\(clientInfo.requested.host)\(req.url.string)"
            Log.info("with request uri: \(url)", requestId: req.id)

            return try await LoginController.renderLoginView(
                on: req,
                status: .unauthorized,
                error: nil,
                props: PageProperties(
                    title: "Login for a authorisation code",
                    requestUri: req.url.string, // UIT-372
                    tenant: clientInfo.tenant
                )
            )
        }

        switch authRequest {
        case .insecure(let authRequest): // https://datatracker.ietf.org/doc/html/rfc7636
            return try await doAuthHandler(on: req, payload: userPayload, authRequest: authRequest)
        case .pkce(let authRequest):
            return try await doAuthHandler(on: req, payload: userPayload, authRequest: authRequest)
        }
    }

    // MARK: - Privates

    /// Validates PKCE requirement for clients that enforce it
    ///
    /// - Parameters:
    ///   - authRequest: The authentication request (insecure or PKCE)
    ///   - req: The current request
    /// - Throws: `Abort` error if client requires PKCE but request is insecure
    private func validatePKCERequirement(authRequest: AuthRequests, on req: Request) async throws {
        if case .insecure = authRequest {
            // For insecure (non-PKCE) requests, check if client requires PKCE
            if let clientId = try? req.query.get(String.self, at: "client_id") {
                let client = await UitsmijterClient.find(in: req.application.entityStorage, clientId: clientId)
                if let client = client, client.config.isPkceOnly ?? false {
                    throw Abort(.badRequest, reason: "LOGIN.ERRORS.CLIENT_ONLY_SUPPORTS_PKCE")
                }
            }
        }
    }

    /// Render the login page
    ///
    /// - Parameters:
    ///   - request: The current request
    ///   - message: An optional custom log message
    /// - Returns:
    /// - Throws:
    private func renderLogin(on request: Request, log message: String?) async throws -> Response {
        Log.info(message ?? "render login", requestId: request.id)

        guard let clientInfo = request.clientInfo else {
            Log.error("Auth request without clientInfo is not allowed", requestId: request.id)
            throw Abort(.badRequest, reason: "LOGIN.ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        let url = "\(clientInfo.requested.scheme)://\(clientInfo.requested.host)/\(request.url.string)"
        Log.info("renderLogin with request uri: \(url)", requestId: request.id)

        return try await LoginController.renderLoginView(
            on: request,
            status: .unauthorized,
            error: nil,
            props: PageProperties(
                title: "Login for a authorisation code",
                requestUri: url,
                tenant: clientInfo.tenant
            )
        )
    }

    /// Doing the authentication for insecure implicit flow
    ///
    /// - Parameters:
    ///   - request: The current request
    ///   - userPayload: the payload of the users token
    ///   - authRequest: the authentication request
    /// - Returns: A response with a code redirect
    /// - Throws: An error if something is not allowed.
    @Sendable func doAuthHandler(
        on request: Request,
        payload userPayload: Payload,
        authRequest: AuthRequest) async throws -> Response {

        let client = try await client(for: authRequest, request: request)
        let clientConfig = client.config
        let foundTenant = await clientConfig.tenant(in: request.application.entityStorage)
        guard let tenant = foundTenant else {
            throw Abort(.badRequest, reason: "LOGIN.ERRORS.MISSING_TENANT")
        }

        if userPayload.tenant != tenant.name {
            throw Abort(.forbidden, reason: "LOGIN.ERRORS.TENANT_MISMATCH")
        }

        if client.config.isPkceOnly ?? false {
            throw Abort(.badRequest, reason: "LOGIN.ERRORS.CLIENT_ONLY_SUPPORTS_PKCE")
        }
        if client.config.secret != nil && client.config.secret != authRequest.client_secret {
            throw Abort(.unauthorized, reason: "LOGIN.ERROR.WRONG_CLIENT_SECRET")
        }
        let redirect = try client.checkedRedirect(for: authRequest)
        let scopes = allowedScopes(on: client, for: authRequest)
        Log.info("""
                 User \(request.clientInfo?.subject ?? "-")
                 got scopes: \(scopes.joined(separator: ","))
                 """, requestId: request.id)

        metricsAuthorizeAttempts?.observe(1, [
            ("client", client.name),
            ("tenant", tenant.name),
            ("type", "insecure")
        ])

        // construct authorisation code
        let code = Code()
        let authSession = AuthSession(
            type: .code,
            state: authRequest.state,
            code: code,
            scopes: scopes,
            payload: userPayload,
            redirect: redirect,
            ttl: Constants.AUTHCODE.TimeToLive
        )

        try await request.application.authCodeStorage?.set(authSession: authSession)
        return authSession.codeRedirect(to: request)
    }

    /// Doing the authentication for pkce flow
    ///
    /// - Parameters:
    ///   - request: The current request
    ///   - userPayload: the payload of the users token
    ///   - authRequest: the authentication request
    /// - Returns: A response with a code redirect
    /// - Throws: An error if something is not allowed.
    @Sendable func doAuthHandler(
        on request: Request,
        payload userPayload: Payload,
        authRequest: AuthRequestPKCE
    ) async throws -> Response {

        let client = try await client(for: authRequest, request: request)
        let clientConfig = client.config
        let foundTenant = await clientConfig.tenant(in: request.application.entityStorage)
        guard let tenant = foundTenant else {
            throw Abort(.badRequest, reason: "LOGIN.ERRORS.MISSING_TENANT")
        }

        if userPayload.tenant != tenant.name {
            throw Abort(.forbidden, reason: "LOGIN.ERRORS.TENANT_MISMATCH")
        }

        if client.config.secret != nil && client.config.secret != authRequest.client_secret {
            throw Abort(.unauthorized, reason: "LOGIN.ERROR.WRONG_CLIENT_SECRET")
        }

        let redirect = try client.checkedRedirect(for: authRequest)
        let scopes = allowedScopes(on: client, for: authRequest)
        Log.info("""
                 User \(request.clientInfo?.subject ?? "-") got scopes: \(scopes.joined(separator: ","))
                 """, requestId: request.id)

        metricsAuthorizeAttempts?.observe(1, [
            ("client", client.name),
            ("tenant", tenant.name),
            ("type", "pkce")
        ])

        // construct authorisation code
        let code = Code(
            codeChallengeMethod: authRequest.code_challenge_method,
            codeChallenge: authRequest.code_challenge
        )
        let authSession = AuthSession(
            type: .code,
            state: authRequest.state,
            code: code,
            scopes: scopes,
            payload: userPayload,
            redirect: redirect,
            ttl: Constants.AUTHCODE.TimeToLive
        )

        try await request.application.authCodeStorage?.set(authSession: authSession)
        return authSession.codeRedirect(to: request)
    }

    private func getCodeChallengeMethod(on request: Request) throws -> CodeChallengeMethod {
        guard let codeChallengeMethod = CodeChallengeMethod(
                rawValue: request.query["code_challenge_method"].map({ $0 as String }) ?? "none")
        else {
            throw Abort(.notImplemented, reason: "LOGIN.ERRORS.CODE_CHALLENGE_METHOD_NOT_IMPLEMENTED")
        }
        return codeChallengeMethod
    }

    private func getAuthRequest(on request: Request, with method: CodeChallengeMethod) throws -> AuthRequests {
        let authRequest: AuthRequests = (
            method == .none
                ? .insecure(try request.query.decode(AuthRequest.self))
                : .pkce(try request.query.decode(AuthRequestPKCE.self))
        )
        return authRequest
    }

}
