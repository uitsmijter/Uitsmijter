import Foundation
import Vapor
import JWT

extension TokenController {

    /// Request handler to return a `Token` for a `GrantType`
    /// Different `GrantTypes` needs a different treatment. This proxy method streamline the implementations for the
    /// controller.
    ///
    /// - Parameters:
    ///   - grant: The requested `GrantTypes`
    ///   - tenant: for the `Tenant`
    ///   - req: On that `Request`
    ///   - scopes: With this `[String]` of scopes.
    ///
    /// - Returns: A `Token` that is constructed for the `GrantType`
    /// - Throws: An `unauthorized` error if there was en error while constructing the token
    func tokenGrantTypeRequestHandler(
            of grant: GrantTypes,
            for tenant: Tenant,
            on req: Request,
            scopes: [String]
    ) async throws -> TokenResponse {
        var token: TokenResponse?

        switch grant {
        case .authorization_code:
            token = try await authorisationTokenGrantTypeRequestHandler(for: tenant, on: req, scopes: scopes)
        case .refresh_token:
            token = try await refreshTokenGrantTypeRequestHandler(for: tenant, on: req, scopes: scopes)
        case .password:
            token = try await passwordGrantTypeRequestHandler(for: tenant, on: req, scopes: scopes)
        default:
            throw Abort(.notImplemented, reason: "ERRORS.GRANT_TYPE_NOT_IMPLEMENTED")
        }

        guard let token else {
            req.requestInfo = RequestInfo(description: "Token failure")
            throw Abort(.unprocessableEntity, reason: "ERRORS.EXPECTED_VALUE_UNSET")
        }

        return token
    }

    // MARK: - Private functions

    private func extendRequestWithRequestInfo(
            _ session: AuthSession,
            _ authorisationTokenRequest: CodeTokenRequest,
            _ req: Request
    ) throws {
        // check code challenge if set
        switch session.code.codeChallengeMethod {
        case .plain:
            if authorisationTokenRequest.code_challenge_method != nil
                       && authorisationTokenRequest.code_challenge_method != session.code.codeChallengeMethod {
                req.requestInfo = RequestInfo(
                        description: "Wrong challenge method (plain). Request: "
                                + """
                                  \(
                                          authorisationTokenRequest.code_challenge_method?.rawValue
                                                  ?? "_no_code_challenge_method"
                                  ),
                                  """.replacingOccurrences(of: "\n", with: "")
                                + "Send: \(session.code.codeChallengeMethod?.rawValue ?? "_no_codeChallengeMethod")"
                )
                throw Abort(.forbidden, reason: "ERRORS.CODE_CHALLENGE_METHOD_MISMATCH")
            }

            if authorisationTokenRequest.code_verifier != session.code.codeChallenge {
                throw Abort(.forbidden, reason: "ERRORS.CODE_CHALLENGE_METHOD_MISMATCH")
            }
        case .sha256:
            if authorisationTokenRequest.code_challenge_method != nil
                       && authorisationTokenRequest.code_challenge_method != session.code.codeChallengeMethod {
                req.requestInfo = RequestInfo(
                        description: "Wrong challenge method (sha256). Request: "
                                + """
                                  \(
                                          authorisationTokenRequest.code_challenge_method?.rawValue
                                                  ?? "_no_code_challenge_method"
                                  ),
                                  """.replacingOccurrences(of: "\n", with: "")
                                + "Send: \(session.code.codeChallengeMethod?.rawValue ?? "_no_codeChallengeMethod")"
                )
                throw Abort(
                        .forbidden,
                        reason: "ERRORS.CODE_CHALLENGE_METHOD_MISMATCH"
                )
            }

            if authorisationTokenRequest.code_challenge != session.code.codeChallenge {
                throw Abort(.forbidden, reason: "ERRORS.CODE_CHALLENGE_METHOD_MISMATCH")
            }

        default:
            Log.debug("Token request without a challenge", request: req)
        }
    }

    private func authorisationTokenGrantTypeRequestHandler(
            for tenant: Tenant,
            on req: Request,
            scopes: [String]
    ) async throws -> TokenResponse {
        let authorisationTokenRequest = try req.content.decode(CodeTokenRequest.self)

        guard let authCodeStorage = req.application.authCodeStorage else {
            throw Abort(.insufficientStorage, reason: "ERRORS.CODE_STORAGE_AVAILABILITY")
        }

        guard let session = authCodeStorage.get(
                type: .code,
                codeValue: authorisationTokenRequest.code,
                remove: true
        )
        else {
            Log.error("There is no code for value \(authorisationTokenRequest.code)", request: req)
            throw Abort(.forbidden, reason: "ERRORS.INVALID_CODE")
        }

        if session.payload?.tenant != tenant.name {
            throw Abort(.forbidden, reason: "ERRORS.TENANT_MISMATCH")
        }

        try extendRequestWithRequestInfo(session, authorisationTokenRequest, req)

        Log.info(
                "Login succeeded \(session.payload?.user ?? "-") with scopes: \(scopes.joined(separator: ","))",
                request: req
        )

        // scopes should come from the login, not from the token request
        // TODO send t priv
        if session.scopes.isEmpty == true && scopes.isEmpty == false {
            Log.warning("""
                        Taking scopes from token request is deprecated and should be avoided
                        tenant \(tenant)
                        """, request: req)
        }
        if (session.scopes.isEmpty == false && scopes.isEmpty == false)
                   && (session.scopes.sorted() != scopes.sorted()) {
            Log.info("Invalid scope request", request: req)
            throw Abort(.forbidden, reason: "ERRORS.INVALID_SCOPES")
        }

        let userScopes = session.scopes.isEmpty == false ? session.scopes : scopes

        let (accessToken, refreshToken) = try getNewTokenPair(
                on: req,
                tenant: tenant,
                session: session,
                scopes: userScopes
        )
        return TokenResponse(
                access_token: accessToken.value,
                token_type: .Bearer,
                expires_in: accessToken.secondsToExpire,
                refresh_token: refreshToken.value,
                scope: userScopes.joined(separator: " ")
        )
    }

    private func refreshTokenGrantTypeRequestHandler(
            for tenant: Tenant,
            on req: Request,
            scopes: [String]
    ) async throws -> TokenResponse {
        let refreshTokenRequest = try req.content.decode(RefreshTokenRequest.self)
        guard let session = req.application.authCodeStorage?.get(
                type: .refresh,
                codeValue: refreshTokenRequest.refresh_token,
                remove: true
        )
        else {
            throw Abort(.forbidden, reason: "ERRORS.INVALID_TOKEN")
        }

        if session.payload?.tenant != tenant.name {
            throw Abort(.forbidden, reason: "ERRORS.TENANT_MISMATCH")
        }

        // handle provider requests
        guard let username = session.payload?.user else {
            throw Abort(.forbidden, reason: "ERRORS.EXPECTED_VALUE_UNSET")
        }

        // Ensure that the user is still valid
        if try await UserValidation.isStillValid(username: username, tenant: tenant, on: req) == false {
            throw Abort(.forbidden, reason: "ERRORS.INVALIDATE")
        }

        Log.info("Refresh succeeded \(session.payload?.user ?? "-")", request: req)

        // scopes should come from the login, not from the token request
        if session.scopes.isEmpty == true && scopes.isEmpty == false {
            Log.warning("""
                        Taking scopes from token request is deprecated and should be avoided
                        tenant \(tenant)
                        """, request: req)
        }
        if (session.scopes.isEmpty == false && scopes.isEmpty == false)
                   && (session.scopes.sorted() != scopes.sorted()) {
            Log.info("Invalid scope request", request: req)
            throw Abort(.forbidden, reason: "ERRORS.INVALID_SCOPES")
        }

        let userScopes = session.scopes.isEmpty == false ? session.scopes : scopes

        let (accessToken, refreshToken) = try getNewTokenPair(on: req, tenant: tenant, session: session, scopes: scopes)
        return TokenResponse(
                access_token: accessToken.value,
                token_type: .Bearer,
                expires_in: accessToken.secondsToExpire,
                refresh_token: refreshToken.value,
                scope: userScopes.joined(separator: " ")
        )
    }

    private func passwordGrantTypeRequestHandler(
            for tenant: Tenant,
            on req: Request,
            scopes: [String]
    ) async throws -> TokenResponse {
        let passwordTokenRequest = try req.content.decode(PasswordTokenRequest.self)

        // handle provider requests
        let providerInterpreter = JavaScriptProvider()
        try providerInterpreter.loadProvider(script: tenant.config.providers.joined(separator: "\n"))
        try await providerInterpreter.start(
                class: .userLogin,
                arguments: JSInputCredentials(
                        username: passwordTokenRequest.username,
                        password: passwordTokenRequest.password
                )
        )

        // Ask the provider if the user can login
        if try providerInterpreter.getValue(class: .userLogin, property: "canLogin") == false {
            Log.info("Can not login user \(passwordTokenRequest.username)", request: req)
            throw Abort(.forbidden, reason: "ERRORS.WRONG_CREDENTIALS")
        }

        Log.info("Login succeeded \(passwordTokenRequest.username)", request: req)

        // get the committed subject
        let providedSubject: SubjectProtocol = Subject.decode(
                from: providerInterpreter.committedResults?.compactMap({ $0 })
        ).first ?? Subject(subject: JWT.SubjectClaim(value: passwordTokenRequest.username))

        let profile = providerInterpreter.getProfile()
        let role = providerInterpreter.getRole()

        let accessToken = try Token(
                tenant: tenant,
                subject: providedSubject.subject,
                userProfile: UserProfile(
                        role: role,
                        user: passwordTokenRequest.username,
                        profile: profile
                )
        )
        return TokenResponse(
                access_token: accessToken.value,
                token_type: .Bearer,
                expires_in: accessToken.secondsToExpire,
                // tokens issued with the implicit grant cannot be issued a refresh token.
                refresh_token: nil,
                scope: scopes.joined(separator: " ")
        )
    }

    func getNewTokenPair(
            on req: Request,
            tenant: Tenant,
            session: AuthSession,
            scopes: [String]
    ) throws -> (access: Token, refresh: Code) {
        guard let payload = session.payload else {
            throw TokenError.NO_PAYLOAD
        }
        let profile = UserProfile(
                role: payload.role,
                user: payload.user,
                profile: payload.profile
        )
        let accessToken = try Token(
                tenant: tenant,
                subject: payload.subject,
                userProfile: profile
        )
        let refreshToken: Code = Code()

        let refreshSession = AuthSession(
                type: .refresh,
                state: session.state,
                code: refreshToken,
                scopes: scopes,
                payload: session.payload,
                redirect: session.redirect,
                ttl: (Int64(Constants.TOKEN.REFRESH_EXPIRATION_IN_HOURS) * 60 * 60)
        )
        try req.application.authCodeStorage?.set(authSession: refreshSession)
        return (access: accessToken, refresh: refreshToken)
    }
}
