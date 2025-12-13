import Foundation
import Vapor
import JWT
import Logger

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
        withScope scope: String?
    ) async throws -> TokenResponse {
        var token: TokenResponse?

        switch grant {
        case .authorization_code:
            token = try await authorisationTokenGrantTypeRequestHandler(for: tenant, on: req)
        case .refresh_token:
            token = try await refreshTokenGrantTypeRequestHandler(for: tenant, on: req)
        case .password:
            token = try await passwordGrantTypeRequestHandler(for: tenant, on: req, scope: scope)
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
            Log.debug("Token request without a challenge", requestId: req.id)
        }
    }

    private func authorisationTokenGrantTypeRequestHandler(
        for tenant: Tenant,
        on req: Request
    ) async throws -> TokenResponse {
        let authorisationTokenRequest = try req.content.decode(CodeTokenRequest.self)

        guard let authCodeStorage = req.application.authCodeStorage else {
            throw Abort(.insufficientStorage, reason: "ERRORS.CODE_STORAGE_AVAILABILITY")
        }

        guard let session = await authCodeStorage.get(
            type: .code,
            codeValue: authorisationTokenRequest.code,
            remove: true
        )
        else {
            Log.error("There is no code for value \(authorisationTokenRequest.code)", requestId: req.id)
            throw Abort(.forbidden, reason: "ERRORS.INVALID_CODE")
        }

        if session.payload?.tenant != tenant.name {
            throw Abort(.forbidden, reason: "ERRORS.TENANT_MISMATCH")
        }

        try extendRequestWithRequestInfo(session, authorisationTokenRequest, req)
        Log.info(
            "Login succeeded \(session.payload?.user ?? "-") with scopes: \(session.payload?.scope ?? "-")",
            requestId: req.id
        )

        let userScopes: String
        if let payloadScope = session.payload?.scope, !payloadScope.isEmpty {
            userScopes = payloadScope
        } else {
            userScopes = session.scopes.sorted().joined(separator: " ")
        }

        let (accessToken, refreshToken) = try await getNewTokenPair(
            on: req,
            tenant: tenant,
            session: session,
            scopes: userScopes.components(separatedBy: " ")
        )
        return TokenResponse(
            access_token: accessToken.value,
            token_type: .Bearer,
            expires_in: accessToken.secondsToExpire,
            refresh_token: refreshToken.value,
            scope: userScopes
        )
    }

    private func refreshTokenGrantTypeRequestHandler(
        for tenant: Tenant,
        on req: Request
    ) async throws -> TokenResponse {
        let refreshTokenRequest = try req.content.decode(RefreshTokenRequest.self)
        guard let session = await req.application.authCodeStorage?.get(
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

        Log.info("Refresh succeeded \(session.payload?.user ?? "-")", requestId: req.id)

        let userScopes: String
        if let payloadScope = session.payload?.scope, !payloadScope.isEmpty {
            userScopes = payloadScope
        } else {
            userScopes = session.scopes.sorted().joined(separator: " ")
        }

        let (accessToken, refreshToken) = try await getNewTokenPair(
            on: req,
            tenant: tenant,
            session: session,
            scopes: userScopes.components(separatedBy: " ")
        )
        return TokenResponse(
            access_token: accessToken.value,
            token_type: .Bearer,
            expires_in: accessToken.secondsToExpire,
            refresh_token: refreshToken.value,
            scope: userScopes
        )
    }

    private func passwordGrantTypeRequestHandler(
        for tenant: Tenant,
        on req: Request,
        scope: String? = ""
    ) async throws -> TokenResponse {
        let passwordTokenRequest = try req.content.decode(PasswordTokenRequest.self)

        // handle provider requests
        let providerInterpreter = JavaScriptProvider()
        try await providerInterpreter.loadProvider(script: tenant.config.providers.joined(separator: "\n"))
        try await providerInterpreter.start(
            class: .userLogin,
            arguments: JSInputCredentials(
                username: passwordTokenRequest.username,
                password: passwordTokenRequest.password
            )
        )

        // Ask the provider if the user can login
        if try await providerInterpreter.getValue(class: .userLogin, property: "canLogin") == false {
            Log.info("Can not login user \(passwordTokenRequest.username)", requestId: req.id)
            throw Abort(.forbidden, reason: "ERRORS.WRONG_CREDENTIALS")
        }

        Log.info("Login succeeded \(passwordTokenRequest.username)", requestId: req.id)

        // get the committed subject
        let committedResults = await providerInterpreter.committedResults
        let providedSubject: SubjectProtocol = Subject.decode(
            from: committedResults?.compactMap({ $0 })
        ).first ?? Subject(subject: JWT.SubjectClaim(value: passwordTokenRequest.username))

        let profile = await providerInterpreter.getProfile()
        let role = await providerInterpreter.getRole()
        let providerScopes = await providerInterpreter.getScopes()
        let finalScopes = Array(Set((scope?.components(separatedBy: " ") ?? []) + providerScopes)).sorted()
        
        // Construct issuer from request
        let scheme = req.headers.first(name: "X-Forwarded-Proto")
            ?? (Constants.TOKEN.isSecure ? "https" : "http")
        let host = req.headers.first(name: "X-Forwarded-Host")
            ?? req.headers.first(name: "Host")
            ?? tenant.config.hosts.first
            ?? Constants.PUBLIC_DOMAIN
        let issuer = "\(scheme)://\(host)"

        // Get client_id for audience
        let tokenRequest = try req.content.decode(TokenRequest.self)

        let accessToken = try await Token(
            issuer: IssuerClaim(value: issuer),
            audience: AudienceClaim(value: tokenRequest.client_id),
            tenantName: tenant.name,
            subject: providedSubject.subject,
            userProfile: UserProfile(
                role: role,
                user: passwordTokenRequest.username,
                scope: finalScopes.joined(separator: " "),
                profile: profile
            ),
            authTime: Date(),
            algorithmString: tenant.config.effectiveJwtAlgorithm,
            signerManager: req.application.signerManager
        )
        
        return TokenResponse(
            access_token: accessToken.value,
            token_type: .Bearer,
            expires_in: accessToken.secondsToExpire,
            // tokens issued with the implicit grant cannot be issued a refresh token.
            refresh_token: nil,
            scope: finalScopes.joined(separator: " ")
        )
    }

    func getNewTokenPair(
        on req: Request,
        tenant: Tenant,
        session: AuthSession,
        scopes: [String]
    ) async throws -> (access: Token, refresh: Code) {
        guard let payload = session.payload else {
            throw TokenError.NO_PAYLOAD
        }
        let profile = UserProfile(
            role: payload.role,
            user: payload.user,
            scope: payload.scope,
            profile: payload.profile
        )

        // Construct issuer from request
        let scheme = req.headers.first(name: "X-Forwarded-Proto")
            ?? (Constants.TOKEN.isSecure ? "https" : "http")
        let host = req.headers.first(name: "X-Forwarded-Host")
            ?? req.headers.first(name: "Host")
            ?? tenant.config.hosts.first
            ?? Constants.PUBLIC_DOMAIN
        let issuer = "\(scheme)://\(host)"

        // Get client_id for audience
        let tokenRequest = try req.content.decode(TokenRequest.self)

        let accessToken = try await Token(
            issuer: IssuerClaim(value: issuer),
            audience: AudienceClaim(value: tokenRequest.client_id),
            tenantName: tenant.name,
            subject: payload.subject,
            userProfile: profile,
            authTime: payload.authTime.value,
            algorithmString: tenant.config.effectiveJwtAlgorithm,
            signerManager: req.application.signerManager
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
        try await req.application.authCodeStorage?.set(authSession: refreshSession)

        // Trigger status update for Kubernetes tenant and client after creating refresh token
        if let tenantName = session.payload?.tenant {
            Log.info("Token created for tenant: \(tenantName), triggering status update")
            // Find client by client_id from the token request
            let tokenRequest = try req.content.decode(TokenRequest.self)
            let client = await Client.find(
                in: req.application.entityStorage,
                clientId: tokenRequest.client_id
            )
            await req.application.entityLoader?.triggerStatusUpdate(for: tenantName, client: client)
        } else {
            Log.warning("No tenant name in session payload, cannot trigger status update")
        }

        return (access: accessToken, refresh: refreshToken)
    }
}
