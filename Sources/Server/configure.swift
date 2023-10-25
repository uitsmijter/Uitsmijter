import Vapor
import Leaf
import Redis
import JWT
import Metrics
import Prometheus
import Logging

enum ApplicationConfigError: Error {
    case directoryConfigError(String)
    case clientWithoutName(String)
    case clientWithoutTenant(String)
    case tenantNotFound(String)
    case tenantNotParsable([String])
}

/// Global ResourcePath
var resourcePath = "./"

/// Configures the application
///
/// - Precondition: Environment variables to set
///                 - LOG_LEVEL
///                 - DIRECTORY
///
/// - Parameter app: Vapor application context
/// - Throws: When the configuration fails, or the routes can't register
///
public func configure(_ app: Application) throws {
    app.logger = Log.main.getLogger()

    app.http.server.configuration.serverName = "\(Constants.APPLICATION)/\(Constants.MAJOR_VERSION)"
    app.http.server.configuration.responseCompression = .enabled
    app.http.server.configuration.requestDecompression = .enabled

    // Errors
    app.middleware = .init()
    app.middleware.use(RequestErrorMiddleware.default(environment: app.environment))

    let preserveResourcesDirectory = app.directory.resourcesDirectory
    if let applicationDirectory = Vapor.Environment.get("DIRECTORY") {
        app.directory = DirectoryConfiguration(workingDirectory: applicationDirectory)
    }
    #if DEBUG
    // Rewrite directories in tests
    if preserveResourcesDirectory.contains("Stubs") {
        app.directory.resourcesDirectory = preserveResourcesDirectory
    }
    #endif
    resourcePath = app.directory.resourcesDirectory

    // Webroot
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // use template engine
    app.views.use(.leaf)
    configureLeafTags(app.leaf)

    // Prometheus
    _ = Prometheus.main.getClient()

    // JWT
    app.jwt.signers.use(jwt_signer)

    // Content Encoder
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    // Main Encoder & Decoder
    JSONEncoder.configureMainEncoder { encoder in
        encoder.dateEncodingStrategy = .iso8601
    }
    JSONDecoder.configureMainDecoder { decoder in
        decoder.dateDecodingStrategy = .iso8601
    }
    // override the global encoder used for the `.json` media type
    ContentConfiguration.global.use(encoder: encoder, for: .json)

    // Version
    Log.info("Uitsmijter Version: \(PackageBuild.info.describe)")

    // sessions
    app.sessions.configuration.cookieName = "\(Constants.APPLICATION.lowercased())"
    if app.environment.isRelease || ProcessInfo.processInfo.environment["ENVIRONMENT"] == "production" {
        Log.info("Boot redis")
        app.redis.configuration = try RedisConfiguration(
                hostname: ProcessInfo.processInfo.environment["REDIS_HOST"] ?? "localhost",
                port: 6379,
                password: ProcessInfo.processInfo.environment["REDIS_PASSWORD"],
                database: 0,
                pool: .init(
                        maximumConnectionCount: .maximumActiveConnections(16),
                        minimumConnectionCount: 2,
                        connectionBackoffFactor: 2,
                        initialConnectionBackoffDelay: .seconds(1000),
                        connectionRetryTimeout: nil
                )
        )
        app.sessions.use(.redis(delegate: AuthSessionDelegate()))
        app.authCodeStorage = .init(use: .redis(client: app.redis))
    } else {
        app.logger.warning(
                "Sessions are stored in memory, DO NOT USE THIS IN PRODUCTION. -> build a release version instead"
        )
        app.sessions.use(.memory)
        app.authCodeStorage = .init(use: .memory)
    }
    app.sessions.configuration.cookieFactory = { sessionID in
        .init(
                string: sessionID.string,
                maxAge: Constants.COOKIE.EXPIRATION_DAYS * (24 * 60 * 60 * 1000),
                isSecure: true,
                sameSite: .strict
        )
    }

    app.middleware.use(app.sessions.middleware)

    // CORS
    let cors = CORSMiddleware(configuration: CrossOriginResourceSharing.Configuration)
    app.middleware.use(cors, at: .beginning)

    // load entity configuration
    try EntityLoader(storage: EntityStorage.shared)

    // register routes
    try routes(app)
}
