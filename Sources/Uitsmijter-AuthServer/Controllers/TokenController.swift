import Foundation
import Vapor
import Logger

/// Controller implementing OAuth 2.0 token endpoint functionality.
///
/// The `TokenController` provides the OAuth 2.0 `/token` endpoint for obtaining
/// and exchanging access tokens. It supports multiple grant types and validates
/// client credentials and authorization codes according to RFC 6749.
///
/// ## OAuth 2.0 Flows Supported
///
/// - **Authorization Code**: Exchange authorization code for access token
/// - **Refresh Token**: Exchange refresh token for new access token
/// - **Client Credentials**: Machine-to-machine authentication (if configured)
///
/// ## Route Registration
///
/// Registers:
/// - `POST /token` - Exchange credentials/codes for access tokens
/// - `GET /token/info` - Retrieve user profile from valid token
///
/// ## Token Request Flow
///
/// 1. Client POSTs to `/token` with grant type and credentials
/// 2. Controller validates client ID and secret (if required)
/// 3. Verifies grant type is allowed for the client
/// 4. Delegates to appropriate grant type handler
/// 5. Generates and returns access token with metadata
///
/// ## Security Validations
///
/// - Client secret verification (if configured)
/// - Grant type allowlist checking per client
/// - Redirect URI validation
/// - Authorization code expiration checking
/// - PKCE verification for public clients
///
/// ## Example Token Request
///
/// ```http
/// POST /token
/// Content-Type: application/x-www-form-urlencoded
///
/// grant_type=authorization_code
/// &code=abc123
/// &redirect_uri=https://app.example.com/callback
/// &client_id=my-app
/// &client_secret=secret123
/// &code_verifier=xyz789
/// ```
///
/// ## Example Token Response
///
/// ```json
/// {
///   "access_token": "eyJhbGciOiJIUzI1NiIs...",
///   "token_type": "Bearer",
///   "expires_in": 3600,
///   "refresh_token": "def456",
///   "scope": "read profile"
/// }
/// ```
///
/// - Note: Implements OAuth 2.0 RFC 6749 token endpoint specification.
/// - SeeAlso: ``TokenRequest`` for request structure
/// - SeeAlso: ``TokenResponse`` for response structure
/// - SeeAlso: ``OAuthControllerProtocol`` for shared OAuth functionality
/// - SeeAlso: [RFC 6749 - The OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
struct TokenController: RouteCollection, OAuthControllerProtocol {

    /// Registers token endpoint routes with the application.
    ///
    /// - Parameter routes: The routes builder to register endpoints with.
    /// - Throws: Routing configuration errors.
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("token")
        auth.post(use: { @Sendable (req: Request) async throws -> TokenResponse in
            try await self.requestToken(req: req)
        })
        auth.get(["info"], use: { @Sendable (req: Request) async throws -> Response in
            try await self.getTokenInfo(req: req)
        })
    }

    @Sendable func requestToken(req: Request) async throws -> TokenResponse {
        let tokenRequest = try req.content.decode(TokenRequest.self)
        Log.info("""
                 Request Token \(tokenRequest.grant_type.rawValue)
                 client: \(tokenRequest.client_id)
                 with scopes: \(tokenRequest.scope ?? "")
                 """, requestId: req.id)

        let client = try await client(for: tokenRequest, request: req)
        if client.config.secret != nil && client.config.secret != tokenRequest.client_secret {
            Prometheus.main.oauthFailure?.inc(1, [
                ("tenant", client.config.tenantname),
                ("client", client.name),
                ("grant_type", tokenRequest.grant_type.rawValue),
                ("reason", "WRONG_CLIENT_SECRET")
            ])
            throw Abort(.unauthorized, reason: "ERROR.WRONG_CLIENT_SECRET")
        }

        if client.config.grant_types?.contains(where: { $0 == tokenRequest.grant_type.rawValue }) != true {
            let grantTypesDescriptions: String? = client.config.grant_types?.joined(separator: ", ")

            Log.error(
                """
                    Token request grant type '\(tokenRequest.grant_type)' is not allowed
                    by client \(client.name): [\(grantTypesDescriptions ?? "no_grant_types")]
                    """, requestId: req.id)

            Prometheus.main.oauthFailure?.inc(1, [
                ("tenant", client.config.tenantname),
                ("client", client.name),
                ("grant_type", tokenRequest.grant_type.rawValue),
                ("reason", "UNSUPPORTED_GRANT_TYPE")
            ])
            throw Abort(.badRequest, reason: "ERROR.UNSUPPORTED_GRANT_TYPE")
        }

        do {
            let clientConfig = client.config
            let foundTenant = await clientConfig.tenant(in: req.application.entityStorage)
            guard let tenant = foundTenant else {
                throw ClientError.clientHasNoTenant
            }

            let tokenResponse = try await tokenGrantTypeRequestHandler(
                of: tokenRequest.grant_type,
                for: tenant,
                on: req,
                scopes: allowedScopes(on: client, for: tokenRequest.scope?.components(separatedBy: .whitespacesAndNewlines) ?? [])
            )
            Prometheus.main.oauthSuccess?.inc(1, [
                ("tenant", tenant.name),
                ("client", client.name),
                ("grant_type", tokenRequest.grant_type.rawValue),
                ("token_type", tokenResponse.token_type.rawValue)
            ])

            return tokenResponse
        } catch {
            Prometheus.main.oauthFailure?.inc(1, [
                ("tenant", client.config.tenantname),
                ("client", client.name),
                ("grant_type", tokenRequest.grant_type.rawValue),
                ("reason", error.localizedDescription)
            ])
            throw error
        }
    }

    /// Returns a json of the payloads profile of the requesting authenticated user.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: A `Response` with a json encoded profile
    /// - Throws: An error if the user is not authenticated, or something wend wrong with the serialisation.
    @Sendable func getTokenInfo(req: Request) async throws -> Response {
        // Extract Bearer token from Authorization header
        guard let authHeader = req.headers[.authorization].first,
              authHeader.hasPrefix("Bearer "),
              let tokenString = authHeader.split(separator: " ", maxSplits: 1).last.map(String.init) else {
            Log.warning("Missing or invalid Authorization header in token info request", requestId: req.id)
            throw Abort(.unauthorized, reason: "ERRORS.INVALID_TOKEN")
        }

        do {
            // Use SignerManager to verify token (supports both HS256 and RS256)
            let signerManager = req.application.signerManager ?? SignerManager.shared
            let payload = try await signerManager.verify(tokenString, as: Payload.self)

            do {
                try payload.expiration.verifyNotExpired(currentDate: Date())
            } catch {
                Log.info("""
                         Token is expired for \(payload.subject) tenant: \(req.clientInfo?.tenant?.name ?? "-")
                         """, requestId: req.id)
                throw Abort(.unauthorized, reason: "ERRORS.EXPIRED_TOKEN")
            }
            // We do not return a Codable here, because payload.profile is an untyped structure that we have to
            // build anyway. For future updates: Profile has to conform to ResponseEncodable.
            let profile = try JSONEncoder.main.encode(payload.profile)

            let response = Response(
                body: .init(data: profile)
            )
            response.status = .ok
            response.headers.add(name: "Content-Type", value: "application/json")

            return response
        } catch {
            Log.error("Token verification failed: \(error)", requestId: req.id)
            throw Abort(.unauthorized, reason: "ERRORS.INVALID_TOKEN")
        }
    }
}
