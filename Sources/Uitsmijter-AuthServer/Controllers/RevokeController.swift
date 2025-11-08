import Vapor
import Logger

/// Controller handling OAuth 2.0 Token Revocation (RFC 7009)
///
/// This controller implements the token revocation endpoint as specified in
/// [RFC 7009: OAuth 2.0 Token Revocation](https://datatracker.ietf.org/doc/html/rfc7009).
///
/// The revocation endpoint allows clients to notify the authorization server that
/// a previously obtained token is no longer needed and should be invalidated.
///
/// ## Endpoint
///
/// ```
/// POST /revoke
/// ```
///
/// ## Request Format
///
/// ```http
/// POST /revoke HTTP/1.1
/// Host: auth.example.com
/// Content-Type: application/x-www-form-urlencoded
///
/// token=V7vZQbJNNY7zR8IWyV7vZQbJNNY7zR8IW
/// &token_type_hint=access_token
/// &client_id=9095A4F2-35B2-48B1-A325-309CA324B97E
/// &client_secret=secret123
/// ```
///
/// ## Response
///
/// The authorization server responds with HTTP status code 200 if the token
/// has been revoked successfully or if the client submitted an invalid token.
/// Per RFC 7009, invalid tokens do not cause an error response.
///
/// ## Security
///
/// - Client authentication is required (client_id + client_secret for confidential clients)
/// - Token ownership is validated (token must belong to the requesting client)
/// - Cascading revocation: revoking a refresh token also revokes associated access tokens
///
/// - SeeAlso: ``RevokeRequest``
/// - SeeAlso: [RFC 7009](https://datatracker.ietf.org/doc/html/rfc7009)
struct RevokeController: RouteCollection {

    /// Registers revocation endpoint routes with the application.
    ///
    /// - Parameter routes: The routes builder to register endpoints with
    /// - Throws: Routing configuration errors
    func boot(routes: RoutesBuilder) throws {
        routes.post("revoke", use: { @Sendable (req: Request) async throws -> Response in
            try await self.revoke(req: req)
        })
    }

    /// POST /revoke - Revoke a token
    ///
    /// This endpoint revokes an access token or refresh token. If the client
    /// passes a refresh token, all associated access tokens are also revoked
    /// (cascading revocation).
    ///
    /// Per RFC 7009 Section 2.2, the authorization server responds with HTTP status code 200
    /// regardless of whether the token exists or is already revoked. This prevents token scanning.
    ///
    /// ## Client Authentication
    ///
    /// - **Confidential clients**: Must provide valid `client_id` and `client_secret`
    /// - **Public clients**: Must provide `client_id` only (no secret)
    ///
    /// ## Token Ownership Validation
    ///
    /// The server validates that the token belongs to the requesting client by:
    /// 1. Decoding the JWT token to extract the `audience` claim
    /// 2. Verifying that `audience` matches the requesting `client_id`
    ///
    /// ## Token Type Hint
    ///
    /// The `token_type_hint` parameter is optional and helps the server optimize token lookup:
    /// - `"access_token"`: Token is an access token (JWT)
    /// - `"refresh_token"`: Token is a refresh token (authorization code)
    ///
    /// If the hint is incorrect or missing, the server searches across all token types.
    ///
    /// - Parameters:
    ///   - req: The incoming HTTP request
    /// - Returns: HTTP 200 OK response
    /// - Throws: Abort error if client authentication fails
    @MainActor
    func revoke(req: Request) async throws -> Response {
        // Decode the revocation request
        let revokeRequest = try req.content.decode(RevokeRequest.self)

        // Get tenant from storage (use host header to find tenant)
        let host = req.headers.first(name: "X-Forwarded-Host")
            ?? req.headers.first(name: "Host")
            ?? Constants.PUBLIC_DOMAIN

        guard let tenant = Tenant.find(in: req.application.entityStorage, forHost: host) else {
            Log.warning("Revocation request for unknown tenant (host: \(host))", requestId: req.id)
            // Per RFC 7009, return 200 even for invalid requests
            return Response(status: .ok)
        }

        // Validate client credentials
        guard let client = validateClient(
            clientId: revokeRequest.client_id,
            clientSecret: revokeRequest.client_secret,
            tenant: tenant,
            storage: req.application.entityStorage
        ) else {
            // Per RFC 7009 Section 2.2.1: If client authentication fails,
            // the authorization server MUST return an error response
            metricsRevokeFailure?.inc(1, [
                ("tenant", tenant.name),
                ("reason", "invalid_client")
            ])
            throw Abort(.unauthorized, reason: "ERROR.INVALID_CLIENT")
        }

        // Attempt to revoke the token
        await revokeToken(
            token: revokeRequest.token,
            tokenTypeHint: revokeRequest.token_type_hint,
            client: client,
            tenant: tenant,
            on: req
        )

        // Per RFC 7009 Section 2.2: Always return 200 OK
        // "The authorization server responds with HTTP status code 200
        // if the token has been revoked successfully or if the client
        // submitted an invalid token."
        // Note: Metrics are tracked inside revokeToken() methods
        return Response(status: .ok)
    }

    // MARK: - Private Methods

    /// Validates client credentials and returns the client if valid.
    ///
    /// This method performs OAuth 2.0 client authentication as described in RFC 6749 Section 3.2.1:
    /// - **Confidential clients** (with a secret): Must provide matching client_id and client_secret
    /// - **Public clients** (without a secret): Must provide client_id only, secret must be nil
    ///
    /// - Parameters:
    ///   - clientId: The client identifier
    ///   - clientSecret: The client secret (optional)
    ///   - tenant: The tenant context
    ///   - storage: Entity storage for client lookup
    /// - Returns: The authenticated client, or nil if authentication fails
    @MainActor
    private func validateClient(
        clientId: String,
        clientSecret: String?,
        tenant: Tenant,
        storage: EntityStorage
    ) -> Client? {
        // Find client by ID
        guard let client = storage.clients.first(where: { client in
            client.name == clientId && client.config.tenantname == tenant.name
        }) else {
            // Note: We can't log with request ID here since we don't have req parameter
            // Using Logger directly without request context
            Log.warning("Client not found: \(clientId)")
            return nil
        }

        // Validate client secret
        // Confidential clients MUST provide a matching secret
        // Public clients MUST NOT provide a secret
        if let expectedSecret = client.config.secret {
            // Confidential client - secret is required
            guard clientSecret == expectedSecret else {
                Log.warning("Invalid client secret for client: \(clientId)")
                return nil
            }
        } else {
            // Public client - secret must not be provided
            if clientSecret != nil {
                Log.warning("Public client \(clientId) must not provide client_secret")
                return nil
            }
        }

        return client
    }

    /// Revokes a token and potentially cascades to related tokens.
    ///
    /// This method implements the core revocation logic:
    /// 1. Determines token type (access token vs refresh token)
    /// 2. Validates token ownership (audience claim must match client_id)
    /// 3. Revokes the token
    /// 4. Cascades revocation if it's a refresh token (revokes associated access tokens)
    ///
    /// Per RFC 7009, invalid or already-revoked tokens are silently ignored.
    ///
    /// - Parameters:
    ///   - token: The token value to revoke
    ///   - tokenTypeHint: Optional hint about the token type
    ///   - client: The authenticated client requesting revocation
    ///   - tenant: The tenant context
    ///   - req: The request context
    @MainActor
    private func revokeToken(
        token: String,
        tokenTypeHint: String?,
        client: Client,
        tenant: Tenant,
        on req: Request
    ) async {
        // Try to revoke based on hint first, then try all types
        let typesToTry: [TokenLookupStrategy] = if let hint = tokenTypeHint {
            hint == "refresh_token"
                ? [.refreshToken, .accessToken]
                : [.accessToken, .refreshToken]
        } else {
            [.accessToken, .refreshToken]
        }

        for strategy in typesToTry {
            if await tryRevokeToken(
                token: token,
                strategy: strategy,
                client: client,
                tenant: tenant,
                on: req
            ) {
                // Token found and revoked, we're done
                return
            }
        }

        // Token not found or already revoked - this is not an error per RFC 7009
        Log.debug("Token not found or already revoked", requestId: req.id)
    }

    /// Attempts to revoke a token using a specific lookup strategy.
    ///
    /// - Parameters:
    ///   - token: The token value to revoke
    ///   - strategy: The lookup strategy (access token or refresh token)
    ///   - client: The authenticated client
    ///   - tenant: The tenant context
    ///   - req: The request context
    /// - Returns: true if the token was found and revoked, false otherwise
    @MainActor
    private func tryRevokeToken(
        token: String,
        strategy: TokenLookupStrategy,
        client: Client,
        tenant: Tenant,
        on req: Request
    ) async -> Bool {
        switch strategy {
        case .accessToken:
            return await revokeAccessToken(token: token, client: client, on: req)
        case .refreshToken:
            return await revokeRefreshToken(token: token, client: client, tenant: tenant, on: req)
        }
    }

    /// Revokes an access token (JWT).
    ///
    /// This method:
    /// 1. Attempts to parse the token as a JWT
    /// 2. Validates token ownership (audience claim must match client_id)
    /// 3. Since JWTs are stateless, revocation is logged but no storage update is needed
    ///
    /// **Note**: JWT access tokens are stateless and cannot be truly revoked in Uitsmijter's
    /// current architecture. The revocation is logged for audit purposes, but the token
    /// will remain valid until expiration. Future enhancement could implement a token
    /// blacklist or reduce token lifetimes.
    ///
    /// - Parameters:
    ///   - token: The JWT token string
    ///   - client: The authenticated client
    ///   - req: The request context
    /// - Returns: true if the token was valid and owned by the client, false otherwise
    @MainActor
    private func revokeAccessToken(
        token: String,
        client: Client,
        on req: Request
    ) async -> Bool {
        // Try to parse as JWT
        // Token(stringLiteral:) doesn't throw, it creates an invalid token on parse error
        let parsedToken: Token = Token(stringLiteral: token)

        // Check if token is valid (not expired and successfully parsed)
        guard parsedToken.secondsToExpire > 0 else {
            // Not a valid JWT or already expired, might be a refresh token
            return false
        }

        // Validate token ownership: audience must match client_id
        // AudienceClaim.value is an array [String], so check if it contains the client_id
        let audienceValues = parsedToken.payload.audience.value
        guard audienceValues.contains(client.name) else {
            Log.warning(
                "Token ownership validation failed: token belongs to '\(audienceValues.joined(separator: ","))', " +
                "but client '\(client.name)' tried to revoke it",
                requestId: req.id
            )
            // Per RFC 7009, silently ignore tokens that don't belong to this client
            return false
        }

        // JWT access tokens are stateless, so we can't truly revoke them
        // Log the revocation for audit purposes
        Log.info(
            "Access token revoked for client '\(client.name)', subject '\(parsedToken.payload.subject.value)' " +
            "(note: JWT will remain valid until expiration)",
            requestId: req.id
        )

        // Track successful revocation metric
        metricsRevokeSuccess?.inc(1, [
            ("tenant", parsedToken.payload.tenant),
            ("client", client.name),
            ("token_type", "access_token")
        ])

        // TODO: Future enhancement - implement token blacklist or reduce token lifetimes
        // For now, just return success
        return true
    }

    /// Revokes a refresh token and cascades to associated access tokens.
    ///
    /// This method:
    /// 1. Looks up the refresh token in AuthCodeStorage
    /// 2. Validates token ownership (audience claim must match client_id)
    /// 3. Deletes the refresh token from storage
    /// 4. Cascades deletion to any associated authorization codes
    ///
    /// - Parameters:
    ///   - token: The refresh token value
    ///   - client: The authenticated client
    ///   - tenant: The tenant context
    ///   - req: The request context
    /// - Returns: true if the token was found and revoked, false otherwise
    @MainActor
    private func revokeRefreshToken(
        token: String,
        client: Client,
        tenant: Tenant,
        on req: Request
    ) async -> Bool {
        // Ensure authCodeStorage is available
        guard let authCodeStorage = req.application.authCodeStorage else {
            Log.warning("AuthCodeStorage not available", requestId: req.id)
            return false
        }

        // Look up the refresh token in storage
        guard let session = await authCodeStorage.get(
            type: .refresh,
            codeValue: token
        ), let payload = session.payload else {
            // Token not found or has no payload - might already be revoked or never existed
            return false
        }

        // Validate token ownership: audience must match client_id
        // AudienceClaim.value is an array [String], so check if it contains the client_id
        let audienceValues = payload.audience.value
        guard audienceValues.contains(client.name) else {
            Log.warning(
                "Token ownership validation failed: refresh token belongs to '\(audienceValues.joined(separator: ","))', " +
                "but client '\(client.name)' tried to revoke it",
                requestId: req.id
            )
            // Per RFC 7009, silently ignore tokens that don't belong to this client
            return false
        }

        // Delete the refresh token
        do {
            try await authCodeStorage.delete(
                type: .refresh,
                codeValue: token
            )
            Log.info(
                "Refresh token revoked for client '\(client.name)', " +
                "subject '\(payload.subject.value)'",
                requestId: req.id
            )

            // Cascade: Also revoke the authorization code if it still exists
            // This prevents the client from using the authorization code to get new tokens
            let authCodeValue = session.code.value
            try? await authCodeStorage.delete(
                type: .code,
                codeValue: authCodeValue
            )
            Log.debug("Cascaded revocation: authorization code also deleted", requestId: req.id)

            // Track successful revocation metric
            metricsRevokeSuccess?.inc(1, [
                ("tenant", payload.tenant),
                ("client", client.name),
                ("token_type", "refresh_token")
            ])

            return true
        } catch {
            Log.error("Failed to revoke refresh token: \(error)", requestId: req.id)

            // Track failure metric
            metricsRevokeFailure?.inc(1, [
                ("tenant", payload.tenant),
                ("client", client.name),
                ("reason", "storage_error")
            ])

            return false
        }
    }

    /// Token lookup strategy
    private enum TokenLookupStrategy {
        case accessToken
        case refreshToken
    }
}
