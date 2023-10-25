import Foundation
import Vapor

struct TokenController: RouteCollection, OAuthControllerProtocol {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("token")
        auth.post(use: requestToken)
        auth.get(["info"], use: getTokenInfo)
    }

    func requestToken(req: Request) async throws -> TokenResponse {
        let tokenRequest = try req.content.decode(TokenRequest.self)
        Log.info("""
                 Request Token \(tokenRequest.grant_type.rawValue)
                 client: \(tokenRequest.client_id)
                 with scopes: \(tokenRequest.scope ?? "")
                 """, request: req)

        let client = try client(for: tokenRequest)
        if client.config.secret != nil && client.config.secret != tokenRequest.client_secret {
            metricsOAuthFailure?.inc(1, [
                ("tenant", client.config.tenantname),
                ("client", client.name),
                ("grant_type", tokenRequest.grant_type.rawValue),
                ("reason", "WRONG_CLIENT_SECRET")
            ])
            throw Abort(.unauthorized, reason: "ERROR.WRONG_CLIENT_SECRET")
        }

        if client.config.grant_types?.contains(where: { $0 == tokenRequest.grant_type }) != true {
            let grantTypesDescriptions: String? = client.config.grant_types.map({ $0.description })

            Log.error(
                    """
                    Token request grant type '\\(tokenRequest.grant_type)' is not allowed
                    by client \(client.name): [\(grantTypesDescriptions ?? "no_grant_types")]
                    """, request: req)

            metricsOAuthFailure?.inc(1, [
                ("tenant", client.config.tenantname),
                ("client", client.name),
                ("grant_type", tokenRequest.grant_type.rawValue),
                ("reason", "UNSUPPORTED_GRANT_TYPE")
            ])
            throw Abort(.badRequest, reason: "ERROR.UNSUPPORTED_GRANT_TYPE")
        }

        do {
            guard let tenant = client.config.tenant else {
                throw ClientError.clientHasNoTenant
            }

            let tokenResponse = try await tokenGrantTypeRequestHandler(
                    of: tokenRequest.grant_type,
                    for: tenant,
                    on: req,
                    scopes: allowedScopes(on: client, for: tokenRequest)
            )
            metricsOAuthSuccess?.inc(1, [
                ("tenant", tenant.name),
                ("client", client.name),
                ("grant_type", tokenRequest.grant_type.rawValue),
                ("token_type", tokenResponse.token_type.rawValue)
            ])

            return tokenResponse
        } catch {
            metricsOAuthFailure?.inc(1, [
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
    func getTokenInfo(req: Request) throws -> Response {
        do {
            let payload = try? req.jwt.verify(as: Payload.self)
            guard let payload else {
                Log.info("ERRORS.INVALID_TOKEN", request: req)
                throw Abort(.unauthorized, reason: "ERRORS.INVALID_TOKEN")
            }

            do {
                try payload.expiration.verifyNotExpired(currentDate: Date())
            } catch {
                Log.info("""
                         Token is expired for \(payload.subject) tenant: \(req.clientInfo?.tenant?.name ?? "-")
                         """, request: req)
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
            Log.error("ERRORS.ENCODE_PAYLOAD_ERROR", request: req)
            throw Abort(.internalServerError, reason: "ERRORS.ENCODE_PAYLOAD_ERROR")
        }
    }
}
