import Vapor
import Foundation

struct AuthorizeController: RouteCollection, OAuthControllerProtocol {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("authorize")
        auth.get(use: doAuth)
    }

    /// GET /authorize - Get an authorize code
    /// https://www.oauth.com/oauth2-servers/server-side-apps/authorization-code/
    ///
    /// - Parameter req: Current request
    /// - Returns: A http response to the requesting user
    /// - Throws: An Error if something can not be parsed correctly
    func doAuth(req: Request) async throws -> Response {

        let codeChallengeMethod = try getCodeChallengeMethod(on: req)
        let authRequest = try getAuthRequest(on: req, with: codeChallengeMethod)
        let clientInfo = try getClientInfo(on: req)

        let loginIdent = try? req.query.decode(LoginId.self)
        if let loginIdent {
            if req.application.authCodeStorage?.pull(loginUuid: loginIdent.loginid) == false {
                throw Abort(.badRequest, reason: "LOGIN.ERRORS.BADLOGINID")
            }
        }

        if loginIdent == nil && clientInfo.client?.config.referrers?.isNotEmpty ?? false {
            Log.debug("Checking referrers for client \(clientInfo.client?.name ?? "-")", request: req)
            guard let referer = clientInfo.referer else {
                Log.error("Request comes without referer", request: req)
                throw Abort(.badRequest, reason: "LOGIN.ERRORS.WRONG_REFERER")
            }
            do {
                try clientInfo.client?.checkedReferer(for: referer)
            } catch ClientError.illegalReferer(let referer, let reason) {
                Log.info("Can not authorize because client referer does not match \(referer). \(reason)", request: req)
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
            Log.info("Silent login is disabled for tenant \(req.clientInfo?.tenant?.name ?? "-")", request: req)
            req.clientInfo?.validPayload = nil
        }

        // if not logged in, redirect to login - than proceed
        // if already logged in, than generate a code.
        guard let userPayload = req.clientInfo?.validPayload else {
            Log.info("No valid token, render login", request: req)

            let url = "\(clientInfo.requested.scheme)://\(clientInfo.requested.host)\(req.url.string)"
            Log.info("with request uri: \(url)", request: req)

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
            return try doAuthHandler(on: req, payload: userPayload, authRequest: authRequest)
        case .pkce(let authRequest):
            return try doAuthHandler(on: req, payload: userPayload, authRequest: authRequest)
        }
    }

    // MARK: - Privates

    /// Render the login page
    ///
    /// - Parameters:
    ///   - request: The current request
    ///   - message: An optional custom log message
    /// - Returns:
    /// - Throws:
    private func renderLogin(on request: Request, log message: String?) async throws -> Response {
        Log.info(message ?? "render login", request: request)

        guard let clientInfo = request.clientInfo else {
            Log.error("Auth request without clientInfo is not allowed", request: request)
            throw Abort(.badRequest, reason: "LOGIN.ERRORS.NOT_ACCEPTABLE_REQUEST")
        }

        let url = "\(clientInfo.requested.scheme)://\(clientInfo.requested.host)/\(request.url.string)"
        Log.info("renderLogin with request uri: \(url)", request: request)

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
    func doAuthHandler(
            on request: Request,
            payload userPayload: Payload,
            authRequest: AuthRequest) throws -> Response {

        let client = try client(for: authRequest)
        guard let tenant = client.config.tenant else {
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
                 """, request: request)

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

        try request.application.authCodeStorage?.set(authSession: authSession)
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
    func doAuthHandler(on request: Request,
                       payload userPayload: Payload,
                       authRequest: AuthRequestPKCE) throws -> Response {

        let client = try client(for: authRequest)
        guard let tenant = client.config.tenant else {
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
                 """, request: request)

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

        try request.application.authCodeStorage?.set(authSession: authSession)
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

    private func getClientInfo(on request: Request) throws -> ClientInfo {
        guard let clientInfo = request.clientInfo else {
            Log.error("Auth request without clientInfo is not allowed", request: request)
            throw Abort(.badRequest, reason: "LOGIN.ERRORS.NOT_ACCEPTABLE_REQUEST")
        }
        return clientInfo
    }
}
