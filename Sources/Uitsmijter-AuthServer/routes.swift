import Vapor

/// Global function that loads all the routes
///
/// - Parameter app: Pass in a vapor application context
/// - Throws: An error when a route can not register
///
func routes(_ app: Application) throws {
    // Middleware that sets a token from a cookie to the header on every request and response
    app.middleware.use(TokenToHeaderMiddleware())
    // Middleware that sets clientInfo and check for valid requests on a existing Tenant
    app.middleware.use(RequestClientMiddleware())

    // Default route for serving `GET /`
    app.get { req in
        req.view.render(
            Template.getPath(page: "index", request: req),
            PageProperties(
                title: "\(Constants.APPLICATION)",
                serviceUrl: "//" + (req.headers["host"].first ?? Constants.PUBLIC_DOMAIN),
                payload: try? req.jwt.verify(as: Payload.self)
            )
        )
    }

    // Register all Uitsmijter routes
    try app.register(collection: HealthController())
    try app.register(collection: VersionsController())
    try app.register(collection: MetricsController())

    // Login / Logout
    try app.register(collection: LoginController())
    try app.register(collection: LogoutController())

    // Interceptor Flow
    try app.register(collection: InterceptorController())

    // OAuth Flow
    try app.register(collection: WellKnownController())
    try app.register(collection: AuthorizeController())
    try app.register(collection: TokenController())
}
