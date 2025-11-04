import Foundation
import Vapor

// MARK: - CORS Configuration

/// Cross-Origin Resource Sharing (CORS) configuration for the authorization server.
///
/// This structure defines the CORS policy that allows web applications on different
/// domains to interact with the Uitsmijter authorization server. The configuration
/// is permissive to support the OAuth2 flow and Traefik ForwardAuth integration.
///
/// ## Security Considerations
///
/// - **Allowed Origins**: Set to `.all` to support dynamic client origins
/// - **Allowed Methods**: Limited to safe methods (GET, POST, HEAD, OPTIONS)
/// - **Credentials**: Supports cookies and authorization headers for authentication
///
/// ## Supported Headers
///
/// The configuration allows a comprehensive set of headers to support:
/// - Standard HTTP headers (Host, Accept, Content-Type, etc.)
/// - Authentication headers (Authorization, Cookie, Set-Cookie)
/// - Proxy headers (X-Forwarded-*, Forwarded)
/// - CORS headers (Access-Control-*)
///
/// ## Usage
///
/// ```swift
/// // In configure.swift
/// app.middleware.use(CORSMiddleware(configuration: CrossOriginResourceSharing.Configuration))
/// ```
///
/// ## Integration with Reverse Proxies
///
/// The configuration is designed to work with Traefik and other reverse proxies,
/// supporting forwarded headers and multi-domain setups.
///
/// ## Topics
///
/// ### Configuration
/// - ``Configuration``
///
/// - SeeAlso: Vapor's `CORSMiddleware`
struct CrossOriginResourceSharing {

    /// The CORS middleware configuration.
    ///
    /// This configuration allows cross-origin requests from any origin, which is
    /// necessary for OAuth2 flows where clients may be hosted on different domains
    /// than the authorization server.
    ///
    /// ## Allowed Methods
    ///
    /// - GET: For authorization endpoints
    /// - POST: For token and login endpoints
    /// - HEAD: For health checks
    /// - OPTIONS: For CORS preflight requests
    ///
    /// ## Allowed Headers
    ///
    /// Includes standard HTTP headers, authentication headers, and proxy forwarding
    /// headers required for OAuth2 and Traefik integration.
    ///
    /// - SeeAlso: Vapor's `CORSMiddleware.Configuration`
    static let Configuration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [
            .GET,
            .POST,
            .HEAD,
            .OPTIONS
        ],
        allowedHeaders: [
            .host,
            .accept,
            .acceptLanguage,
            .authorization,
            .accessControlRequestHeaders, .accessControlAllowCredentials,
            .setCookie,
            .cookie,
            .forwarded,
            .contentType,
            .location,
            .origin,
            .referer,
            .userAgent,
            .accessControlAllowOrigin,
            .xRequestedWith,
            .xForwardedFor,
            .xForwardedHost,
            .xForwardedProto
        ]
    )

}
