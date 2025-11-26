import Vapor
import Leaf
import Redis
import JWT
import JWTKit
import Metrics
import Prometheus
import Logging
import Logger

/// Configures the Vapor application with all necessary middleware, services, and infrastructure.
///
/// This function is the main entry point for application configuration and is called during
/// application startup. It sets up the complete application stack including:
/// - HTTP server configuration
/// - Middleware chain (error handling, file serving, CORS, sessions)
/// - Template engine (Leaf) with custom tags
/// - Session storage (Redis in production, in-memory for development)
/// - OAuth authorization code storage
/// - JWT signing configuration
/// - JSON encoding/decoding strategies
/// - Prometheus metrics collection
/// - Entity loading (Tenants and Clients)
/// - Route registration
///
/// ## Configuration Order
///
/// The configuration sequence is carefully ordered to ensure dependencies are available:
/// 1. Logger initialization
/// 2. HTTP server settings (compression, server name)
/// 3. Error handling middleware
/// 4. Directory configuration
/// 5. Static file serving middleware
/// 6. Template engine setup
/// 7. Metrics and JWT configuration
/// 8. JSON encoder/decoder configuration
/// 9. Session and storage configuration (environment-dependent)
/// 10. CORS middleware
/// 11. Entity loading from files or Kubernetes
/// 12. Route registration
///
/// ## Environment Variables
///
/// The following environment variables control configuration behavior:
///
/// - `LOG_LEVEL`: Controls logging verbosity (e.g., "trace", "debug", "info", "warning", "error")
/// - `DIRECTORY`: Overrides the working directory path
/// - `ENVIRONMENT`: Set to "production" to enable production mode features
/// - `REDIS_HOST`: Redis server hostname (default: "localhost")
/// - `REDIS_PASSWORD`: Redis authentication password (optional)
///
/// ## Environment-Specific Behavior
///
/// ### Production/Release Mode
/// - Uses Redis for session storage with persistence
/// - Enables OAuth authorization code storage in Redis
/// - Configures connection pooling and retry logic
/// - Falls back to in-memory storage if Redis fails
///
/// ### Development Mode
/// - Uses in-memory session storage (non-persistent)
/// - Logs warning about memory storage usage
/// - Preserves stub directories for testing
///
/// ## Error Handling
///
/// - Redis connection failures are caught and logged, with automatic fallback to in-memory storage
/// - Entity loading errors are propagated to prevent startup with invalid configuration
/// - Route registration errors are propagated to prevent incomplete API setup
///
/// ## Example
///
/// ```swift
/// import Vapor
///
/// @main
/// struct Main {
///     static func main() async throws {
///         let app = Application()
///         defer { app.shutdown() }
///
///         try configure(app)
///         try app.run()
///     }
/// }
/// ```
///
/// - Parameter app: The Vapor application instance to configure.
/// - Throws: Configuration errors including route registration failures or entity loading errors.
///
/// - Important: This function must be called on the MainActor as it configures actor-isolated components.
/// - Warning: In-memory session storage is used in development mode and will not persist across restarts.
///
/// - SeeAlso: ``routes(_:)`` for HTTP route configuration
/// - SeeAlso: ``EntityLoader`` for tenant and client entity loading
/// - SeeAlso: ``configureLeafTags(_:)`` for custom template tag registration
@MainActor
public func configure(_ app: Application) async throws {
    // Initialize application logger with the shared logger instance
    app.logger = Log.shared

    // Configure HTTP server identification and compression
    // Server name appears in the "Server" HTTP header
    app.http.server.configuration.serverName = "\(Constants.APPLICATION)/\(Constants.MAJOR_VERSION)"
    app.http.server.configuration.responseCompression = .enabled
    app.http.server.configuration.requestDecompression = .enabled

    // Initialize middleware chain and add error handling as the first middleware
    // This ensures all errors are caught and properly formatted
    app.middleware = .init()
    app.middleware.use(RequestErrorMiddleware.default(environment: app.environment))

    // Configure directory paths, with support for environment variable override
    let preserveResourcesDirectory = app.directory.resourcesDirectory
    if let applicationDirectory = Vapor.Environment.get("DIRECTORY") {
        app.directory = DirectoryConfiguration(workingDirectory: applicationDirectory)
    }
    #if DEBUG
    // In debug/test mode, preserve stub directories for testing
    // This allows tests to use fixture data from the Stubs directory
    if preserveResourcesDirectory.contains("Stubs") {
        app.directory.resourcesDirectory = preserveResourcesDirectory
    }
    #endif
    // Store directory paths in global variables for access throughout the application
    resourcePath = app.directory.resourcesDirectory
    viewsPath = app.directory.viewsDirectory

    // Add static file serving middleware for public assets (CSS, JS, images, etc.)
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Configure Leaf template engine and register custom tags
    app.views.use(.leaf)
    configureLeafTags(app.leaf)

    // Initialize Prometheus metrics client for application monitoring
    _ = Prometheus.main.getClient()

    // Configure JWT signing and verification keys for Vapor's JWT middleware
    // The HS256 key is always available, RSA keys are added dynamically from KeyStorage
    let hmacKey = HMACKey(from: [UInt8](jwtSecret.utf8))
    await app.jwt.keys.add(hmac: hmacKey, digestAlgorithm: .sha256)

    // Configure JSON encoding/decoding strategies
    // This encoder is used for HTTP responses with the .json content type
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    // Configure the main encoder and decoder used throughout the application
    // Both encoder and decoder must use the same date strategy for Redis storage
    // Using .iso8601 for both to ensure LoginSession serialization works correctly
    JSONEncoder.configureMainEncoder { encoder in
        encoder.dateEncodingStrategy = .iso8601
    }
    JSONDecoder.configureMainDecoder { decoder in
        decoder.dateDecodingStrategy = .iso8601
    }
    // Set the global encoder for all HTTP JSON responses
    ContentConfiguration.global.use(encoder: encoder, for: .json)

    // Log the application version for deployment tracking and debugging
    Log.info("Uitsmijter Version: \(PackageBuild.info.describe)")

    // Configure session management with environment-specific storage backend
    app.sessions.configuration.cookieName = "\(Constants.APPLICATION.lowercased())"

    // Use Redis for session storage in production/release builds for persistence and scalability
    if app.environment.isRelease || ProcessInfo.processInfo.environment["ENVIRONMENT"] == "production" {
        do {
            // Configure Redis connection with connection pooling and retry logic
            // TEST: Using only 1 connection to eliminate connection pooling as a variable
            app.redis.configuration = try RedisConfiguration(
                hostname: ProcessInfo.processInfo.environment["REDIS_HOST"] ?? "localhost",
                port: 6379,
                password: ProcessInfo.processInfo.environment["REDIS_PASSWORD"],
                database: 0,
                pool: .init(
                    maximumConnectionCount: .maximumActiveConnections(16),
                    minimumConnectionCount: 0,
                    connectionBackoffFactor: 2,  // Exponential backoff multiplier
                    initialConnectionBackoffDelay: .milliseconds(100),
                    connectionRetryTimeout: .seconds(5)
                )
            )
            app.logger.warning("DEBUG: Redis connection pool configured with ONLY 1 connection for testing")
            // Enable Redis-backed session storage with custom delegate for serialization
            app.sessions.use(.redis(delegate: AuthSessionDelegate()))
            // Store OAuth authorization codes in Redis for distributed deployments
            app.authCodeStorage = .init(use: .redis(client: app.redis))
            // Store RSA keys in Redis for distributed deployments (supports HPA/multi-pod)
            // IMPORTANT: Use shared KeyGenerator to avoid unnecessary instances
            let keyStorage = KeyStorage(use: .redis(client: app.redis))
            app.keyStorage = keyStorage
            // Configure SignerManager to use the same KeyStorage instance
            app.signerManager = SignerManager(keyStorage: keyStorage)
        } catch {
            // If Redis connection fails, fall back to in-memory storage to keep the application running
            app.logger.error("Failed to configure Redis: \(error). Falling back to in-memory session storage.")
            app.sessions.use(.memory)
            app.authCodeStorage = .init(use: .memory)
            // Fallback to in-memory key storage
            let keyStorage = KeyStorage(use: .memory)
            app.keyStorage = keyStorage
            app.signerManager = SignerManager(keyStorage: keyStorage)
        }
    } else {
        // Development mode: use in-memory storage (sessions lost on restart)
        app.logger.warning(
            "Sessions are stored in memory, DO NOT USE THIS IN PRODUCTION. -> build a release version instead"
        )
        app.sessions.use(.memory)
        app.authCodeStorage = .init(use: .memory)
        // Use in-memory key storage for development
        let keyStorage = KeyStorage(use: .memory)
        app.keyStorage = keyStorage
        app.signerManager = SignerManager(keyStorage: keyStorage)
    }

    // Configure session cookie settings for security and expiration
    app.sessions.configuration.cookieFactory = { sessionID in
        .init(
            string: sessionID.string,
            maxAge: Constants.COOKIE.EXPIRATION_DAYS * (24 * 60 * 60 * 1000),
            isSecure: true,        // Requires HTTPS
            sameSite: .strict      // Prevents CSRF attacks
        )
    }

    // Add session middleware to handle cookie-based session management
    app.middleware.use(app.sessions.middleware)

    // Configure CORS (Cross-Origin Resource Sharing) for API access from web browsers
    // Added at the beginning to ensure CORS headers are set before other middleware
    let cors = CORSMiddleware(configuration: CrossOriginResourceSharing.Configuration)
    app.middleware.use(cors, at: .beginning)

    // Load tenant and client entity configurations from files or Kubernetes CRDs
    // This must happen before route registration to ensure entities are available
    // Store the entity loader so it can be properly shut down during app lifecycle
    app.entityLoader = try EntityLoader(storage: app.entityStorage)

    // Wire up authCodeStorage to entity loader for status updates
    if let storage = app.authCodeStorage {
        app.entityLoader?.setAuthCodeStorage(storage)
    }

    // Register all HTTP routes and controllers
    try routes(app)
}
