import Foundation
import Vapor

// swiftlint:disable identifier_name
/// Builder for constructing OpenID Provider Metadata from tenant and application configuration.
///
/// This actor is responsible for assembling the complete OpenID Connect Discovery metadata
/// for a specific tenant, incorporating tenant-specific settings, aggregating client capabilities,
/// and providing sensible defaults for all fields.
///
/// ## Multi-Tenant Support
///
/// The builder constructs tenant-specific metadata by:
/// - Using the tenant's domain as the issuer
/// - Aggregating supported scopes from all clients in the tenant
/// - Aggregating supported grant types from all clients in the tenant
/// - Using tenant-specific policy URLs if available
///
/// ## Usage
///
/// ```swift
/// let builder = OpenidConfigurationBuilder()
/// let config = await builder.build(
///     for: tenant,
///     request: request,
///     storage: entityStorage
/// )
/// ```
///
/// - SeeAlso: ``OpenidConfiguration``
/// - SeeAlso: ``Tenant``
actor OpenidConfigurationBuilder {

    // MARK: - Default Values

    /// Default supported response types.
    ///
    /// Uitsmijter currently supports the authorization code flow.
    private static let defaultResponseTypes = ["code"]

    /// Default supported subject types.
    ///
    /// Uitsmijter uses public subject identifiers.
    private static let defaultSubjectTypes = ["public"]

    /// Default supported ID token signing algorithms.
    ///
    /// Based on the JWT signing capabilities in the system.
    private static let defaultIdTokenSigningAlgorithms = ["RS256"]

    /// Default supported scopes.
    ///
    /// Basic OpenID Connect scopes that are always available.
    private static let defaultScopes = ["openid", "profile", "email"]

    /// Default supported grant types.
    ///
    /// Standard OAuth 2.0 grant types supported by Uitsmijter.
    private static let defaultGrantTypes = ["authorization_code", "refresh_token"]

    /// Default supported claims.
    ///
    /// Standard claims that Uitsmijter can provide.
    private static let defaultClaims = [
        "sub",
        "iss",
        "aud",
        "exp",
        "iat",
        "auth_time",
        "name",
        "email",
        "email_verified",
        "tenant"
    ]

    /// Default supported token endpoint authentication methods.
    private static let defaultTokenEndpointAuthMethods = [
        "client_secret_post",
        "client_secret_basic",
        "none"
    ]

    /// Default supported PKCE code challenge methods.
    private static let defaultCodeChallengeMethods = ["S256", "plain"]

    /// Default supported response modes.
    private static let defaultResponseModes = ["query", "fragment"]

    // MARK: - Initialization

    /// Initialize a new OpenID Configuration builder.
    init() {}

    // MARK: - Public Methods

    /// Build OpenID Provider Metadata for a specific tenant.
    ///
    /// This method constructs the complete discovery metadata by combining:
    /// - Tenant configuration (hosts, providers, policies)
    /// - Client capabilities (scopes, grant types)
    /// - System defaults
    /// - Request context (scheme, host)
    ///
    /// ## Tenant-Specific Values
    ///
    /// - **issuer**: Constructed from request scheme and host
    /// - **scopes_supported**: Aggregated from all tenant clients + defaults
    /// - **grant_types_supported**: Aggregated from all tenant clients + defaults
    /// - **op_policy_uri**: From tenant's `informations.privacy_url`
    /// - **op_tos_uri**: Could be extended to support tenant-specific ToS
    ///
    /// - Parameters:
    ///   - tenant: The tenant to build configuration for
    ///   - request: The current request (for scheme/host information)
    ///   - storage: Entity storage to access client configurations
    /// - Returns: Complete OpenID Provider Metadata for the tenant
    @MainActor
    func build(
        for tenant: Tenant,
        request: Request,
        storage: EntityStorage
    ) -> OpenidConfiguration {
        // Determine the issuer URL from the request
        let scheme = request.headers.first(name: "X-Forwarded-Proto")
            ?? (Constants.TOKEN.isSecure ? "https" : "http")
        let host = request.headers.first(name: "X-Forwarded-Host")
            ?? request.headers.first(name: "Host")
            ?? tenant.config.hosts.first
            ?? Constants.PUBLIC_DOMAIN

        let issuer = "\(scheme)://\(host)"

        // Get all clients for this tenant
        let tenantClients = storage.clients.filter { client in
            client.config.tenantname == tenant.name
        }

        // Aggregate scopes from all clients
        let aggregatedScopes = aggregateScopes(from: tenantClients)

        // Aggregate grant types from all clients
        let aggregatedGrantTypes = aggregateGrantTypes(from: tenantClients)

        // Aggregate claims (for now use defaults, can be extended)
        let supportedClaims = Self.defaultClaims

        // Build endpoint URLs
        let authorizationEndpoint = "\(issuer)/authorize"
        let tokenEndpoint = "\(issuer)/token"
        let jwksUri = "\(issuer)/.well-known/jwks.json"
        let userinfoEndpoint = "\(issuer)/token/info"

        // Get policy URLs from tenant information
        let policyUri = tenant.config.informations?.privacy_url
        let imprintUri = tenant.config.informations?.imprint_url

        return OpenidConfiguration(
            issuer: issuer,
            authorization_endpoint: authorizationEndpoint,
            token_endpoint: tokenEndpoint,
            jwks_uri: jwksUri,
            response_types_supported: Self.defaultResponseTypes,
            subject_types_supported: Self.defaultSubjectTypes,
            id_token_signing_alg_values_supported: Self.defaultIdTokenSigningAlgorithms,
            userinfo_endpoint: userinfoEndpoint,
            registration_endpoint: nil, // Not currently supported
            scopes_supported: aggregatedScopes,
            claims_supported: supportedClaims,
            response_modes_supported: Self.defaultResponseModes,
            grant_types_supported: aggregatedGrantTypes,
            acr_values_supported: nil,
            token_endpoint_auth_methods_supported: Self.defaultTokenEndpointAuthMethods,
            token_endpoint_auth_signing_alg_values_supported: nil,
            display_values_supported: nil,
            claim_types_supported: nil,
            service_documentation: imprintUri, // Use imprint as service documentation
            claims_locales_supported: nil,
            ui_locales_supported: nil,
            claims_parameter_supported: false,
            request_parameter_supported: false,
            request_uri_parameter_supported: false,
            require_request_uri_registration: false,
            op_policy_uri: policyUri,
            op_tos_uri: nil,
            revocation_endpoint: nil, // Not currently supported
            userinfo_signing_alg_values_supported: nil,
            userinfo_encryption_alg_values_supported: nil,
            userinfo_encryption_enc_values_supported: nil,
            id_token_encryption_alg_values_supported: nil,
            id_token_encryption_enc_values_supported: nil,
            request_object_signing_alg_values_supported: nil,
            request_object_encryption_alg_values_supported: nil,
            request_object_encryption_enc_values_supported: nil,
            code_challenge_methods_supported: Self.defaultCodeChallengeMethods
        )
    }

    // MARK: - Private Methods

    /// Aggregate all unique scopes from tenant clients.
    ///
    /// Combines scopes from all clients in the tenant with the default scopes,
    /// ensuring uniqueness and proper ordering.
    ///
    /// - Parameter clients: The clients to aggregate scopes from
    /// - Returns: Array of unique supported scopes
    @MainActor
    private func aggregateScopes(from clients: [Client]) -> [String] {
        var allScopes = Set(Self.defaultScopes)

        for client in clients {
            if let clientScopes = client.config.scopes {
                allScopes.formUnion(clientScopes)
            }
        }

        return Array(allScopes).sorted()
    }

    /// Aggregate all unique grant types from tenant clients.
    ///
    /// Combines grant types from all clients in the tenant with the default grant types,
    /// ensuring uniqueness.
    ///
    /// - Parameter clients: The clients to aggregate grant types from
    /// - Returns: Array of unique supported grant types
    @MainActor
    private func aggregateGrantTypes(from clients: [Client]) -> [String] {
        var allGrantTypes = Set(Self.defaultGrantTypes)

        for client in clients {
            if let clientGrantTypes = client.config.grant_types {
                allGrantTypes.formUnion(clientGrantTypes)
            }
        }

        return Array(allGrantTypes).sorted()
    }
}
// swiftlint:enable identifier_name
