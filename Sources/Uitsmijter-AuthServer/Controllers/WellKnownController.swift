import Foundation
import Vapor
import Logger

/// Controller for OpenID Connect Discovery endpoints.
///
/// The `WellKnownController` provides OpenID Connect Discovery metadata
/// as specified in the [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata)
/// specification. This allows OAuth/OIDC clients to automatically discover the authorization
/// server's capabilities and endpoint URLs.
///
/// ## Multi-Tenant Support
///
/// This controller supports multi-tenant discovery by:
/// - Resolving the tenant from the request host
/// - Building tenant-specific configuration (issuer, scopes, grant types)
/// - Returning configuration tailored to each tenant's capabilities
///
/// ## Routes
///
/// - `GET /.well-known/openid-configuration` - Returns OIDC discovery metadata
/// - `GET /.well-known/jwks.json` - Returns JSON Web Key Set (JWKS)
///
/// ## Discovery Metadata
///
/// The discovery document includes:
/// - Issuer identifier (tenant-specific)
/// - Authorization endpoint URL
/// - Token endpoint URL
/// - Supported grant types (aggregated from tenant's clients)
/// - Supported response types
/// - Supported scopes (aggregated from tenant's clients)
/// - Token signing algorithms
/// - JWKS URI
/// - Claims supported
///
/// ## Example Response
///
/// ```json
/// {
///   "issuer": "https://auth.example.com",
///   "authorization_endpoint": "https://auth.example.com/authorize",
///   "token_endpoint": "https://auth.example.com/token",
///   "jwks_uri": "https://auth.example.com/.well-known/jwks.json",
///   "response_types_supported": ["code"],
///   "subject_types_supported": ["public"],
///   "id_token_signing_alg_values_supported": ["RS256"],
///   "scopes_supported": ["openid", "profile", "email"],
///   "grant_types_supported": ["authorization_code", "refresh_token"]
/// }
/// ```
///
/// ## Security Considerations
///
/// - The endpoint is publicly accessible (no authentication required)
/// - Returns only capabilities and endpoints, no sensitive data
/// - Validates tenant exists before returning configuration
/// - Uses appropriate HTTP headers (Content-Type, Cache-Control)
///
/// - SeeAlso: [OpenID Connect Discovery 1.0 Specification](https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata)
/// - SeeAlso: ``OpenidConfiguration``
/// - SeeAlso: ``OpenidConfigurationBuilder``
struct WellKnownController: RouteCollection {

    /// Registers well-known routes with the application.
    ///
    /// Registers the OIDC Discovery and JWKS endpoints:
    /// - `/.well-known/openid-configuration` - OIDC Discovery metadata
    /// - `/.well-known/jwks.json` - JSON Web Key Set
    ///
    /// - Parameter routes: The routes builder to register endpoints with.
    /// - Throws: Routing configuration errors.
    func boot(routes: RoutesBuilder) throws {
        let wellKnown = routes.grouped(".well-known")
        wellKnown.get("openid-configuration", use: getConfiguration)
        wellKnown.get("jwks.json", use: getJWKS)
    }

    /// Returns OpenID Provider Metadata for the tenant associated with the request.
    ///
    /// This endpoint implements the OpenID Connect Discovery mechanism, allowing clients
    /// to automatically discover the provider's capabilities and endpoints.
    ///
    /// ## Tenant Resolution
    ///
    /// The tenant is resolved by the ``RequestClientMiddleware`` and attached to the request
    /// as part of ``ClientInfo``. This endpoint uses the helper method to extract it.
    ///
    /// ## Response Format
    ///
    /// - **Content-Type**: `application/json`
    /// - **Status**: 200 OK (on success), 400 Bad Request (if tenant not found)
    /// - **Cache-Control**: Public, max-age=3600 (1 hour)
    ///
    /// ## Error Handling
    ///
    /// - Returns 400 if no tenant matches the request host
    /// - Returns 500 if configuration building fails unexpectedly
    ///
    /// ## Example Request
    ///
    /// ```http
    /// GET /.well-known/openid-configuration HTTP/1.1
    /// Host: auth.example.com
    /// ```
    ///
    /// - Parameter req: The incoming HTTP request
    /// - Returns: The OpenID Provider Metadata as JSON
    /// - Throws: `Abort(.badRequest)` if tenant cannot be resolved
    ///
    /// - SeeAlso: ``OpenidConfiguration``
    /// - SeeAlso: ``OpenidConfigurationBuilder``
    @Sendable
    func getConfiguration(req: Request) async throws -> Response {
        Log.info("OpenID Configuration requested", requestId: req.id)

        // Get clientInfo and tenant using the standard helper methods
        let clientInfo = try req.requireClientInfo()
        let tenant = try req.requireTenant(from: clientInfo)

        Log.info("Building OpenID configuration for tenant: \(tenant.name)", requestId: req.id)

        // Build the configuration using the builder
        let builder = OpenidConfigurationBuilder()
        let configuration = await builder.build(
            for: tenant,
            request: req,
            storage: req.application.entityStorage
        )

        Log.debug("OpenID configuration built successfully for tenant: \(tenant.name)", requestId: req.id)

        // Encode the configuration to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let jsonData = try? encoder.encode(configuration),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Log.error("Failed to encode OpenID configuration to JSON", requestId: req.id)
            throw Abort(.internalServerError, reason: "Failed to generate configuration")
        }

        // Create response with appropriate headers
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json; charset=utf-8")
        headers.add(name: .cacheControl, value: "public, max-age=3600")
        headers.add(name: "X-Content-Type-Options", value: "nosniff")

        Log.info("Returning OpenID configuration for tenant: \(tenant.name)", requestId: req.id)

        return Response(
            status: .ok,
            headers: headers,
            body: .init(string: jsonString)
        )
    }

    /// Returns JSON Web Key Set (JWKS) for JWT verification.
    ///
    /// This endpoint implements RFC 7517 (JSON Web Key) and is referenced by the
    /// `jwks_uri` field in the OpenID Provider Metadata. Clients use this endpoint
    /// to retrieve public keys for verifying JWT signatures.
    ///
    /// ## Response Format
    ///
    /// - **Content-Type**: `application/json; charset=utf-8`
    /// - **Status**: 200 OK
    /// - **Cache-Control**: Public, max-age=3600 (1 hour)
    ///
    /// ## Example Response
    ///
    /// ```json
    /// {
    ///   "keys": [
    ///     {
    ///       "kty": "RSA",
    ///       "use": "sig",
    ///       "kid": "2025-01-08",
    ///       "alg": "RS256",
    ///       "n": "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78...",
    ///       "e": "AQAB"
    ///     }
    ///   ]
    /// }
    /// ```
    ///
    /// ## Key Rotation
    ///
    /// The endpoint may return multiple keys to support key rotation.
    /// Clients should use the `kid` parameter from the JWT header to select
    /// the correct key for verification.
    ///
    /// ## Caching
    ///
    /// Clients should cache the JWKS response for up to 1 hour to reduce load.
    /// The `Cache-Control` header provides caching guidance.
    ///
    /// - Parameter req: The incoming HTTP request
    /// - Returns: The JWKS as JSON
    /// - Throws: `Abort(.internalServerError)` if JWKS generation fails
    ///
    /// - SeeAlso: [RFC 7517 Section 5](https://www.rfc-editor.org/rfc/rfc7517#section-5)
    @Sendable
    func getJWKS(req: Request) async throws -> Response {
        Log.info("JWKS requested", requestId: req.id)

        // Get all public keys from storage
        let keyStorage = KeyStorage.shared

        // Ensure at least one key exists (auto-generates if empty)
        _ = try await keyStorage.getActiveKey()

        let jwkSet = try await keyStorage.getAllPublicKeys()

        Log.debug("JWKS contains \(jwkSet.keys.count) key(s)", requestId: req.id)

        // Encode the JWKS to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(jwkSet),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Log.error("Failed to encode JWKS to JSON", requestId: req.id)
            throw Abort(.internalServerError, reason: "Failed to generate JWKS")
        }

        // Create response with appropriate headers
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json; charset=utf-8")
        headers.add(name: .cacheControl, value: "public, max-age=3600")
        headers.add(name: "X-Content-Type-Options", value: "nosniff")

        Log.info("Returning JWKS with \(jwkSet.keys.count) key(s)", requestId: req.id)

        return Response(
            status: .ok,
            headers: headers,
            body: .init(string: jsonString)
        )
    }

    // MARK: - Helper Methods

}
