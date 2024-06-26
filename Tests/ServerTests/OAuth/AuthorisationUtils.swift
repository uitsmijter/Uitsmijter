import Foundation
import XCTVapor
@testable import Server

enum TestTenantScripts {
    case frodoBaker
    case johnDoe
    case juanPerez
    case ivanIvano
    case custom(String)
}

// swiftlint:disable:next function_body_length
fileprivate func createTenant(
        script: TestTenantScripts,
        name tenantName: String? = nil, 
        hosts: [String]? = [
            "127.0.0.1",
            "example.com",
            "localhost.localdomain",
            "localhost" // we are using localhost for test against our self
        ],
        interceptor: TenantInterceptorSettings? = nil,
        informations: TenantInformations? = nil,
        templates: TenantTemplatesSettings? = nil
) -> Tenant {
    var tenantConfig = TenantSpec(
            hosts: hosts ?? [],
            interceptor: interceptor
    )

    switch script {
    case .frodoBaker:
        tenantConfig.providers.append(
                """
                 class UserLoginProvider {
                    constructor(credentials) { commit(true); }
                    get canLogin() { return true; }
                    get userProfile() { return { name: "Frodo Baker" }; }
                 }
                 class UserValidationProvider {
                    constructor(args) { commit(true); }
                    get isValid() { return true; }
                 }
                """
        )
    case .johnDoe:
        tenantConfig.providers.append(
                """
                class UserLoginProvider {
                    constructor(credentials) {
                        this.valid = false;
                        if(credentials.username === 'valid_user' && credentials.password === 'valid_password'){
                            this.valid = true;
                        }
                        commit(this.valid);
                    }
                    get canLogin() { return this.valid; }
                    get userProfile() { return { name: "John Doe" }; }
                }
                class UserValidationProvider {
                    isValid = false;
                    constructor(args) {
                        if(args.username === 'valid_user'){
                            this.isValid = true;
                        }
                        commit(this.isValid);
                    }
                    get isValid() { return this.isValid; }
                 }
                """
        )
    case .juanPerez:
        tenantConfig.providers.append(
                """
                class UserLoginProvider {
                    constructor(credentials) {
                        this.valid = false;
                        if(credentials.username === 'valid_user' && credentials.password === 'valid_password'){
                            this.valid = true;
                        }
                        commit(this.valid);
                    }
                    get canLogin() { return this.valid; }
                    get userProfile() { return { name: "John Doe" }; }
                }
                class UserValidationProvider {
                    isValid = false;
                    constructor(args) {
                        if(args.username === 'valid_user'){
                            this.isValid = false; // <-- disable refresh
                        }
                        commit(this.isValid);
                    }
                    get isValid() { return this.isValid; }
                 }
                """
        )
    case .ivanIvano:
        tenantConfig.providers.append(
                """
                class UserLoginProvider {
                    constructor(credentials) {
                        this.valid = false;
                        if(credentials.username === 'valid_user' && credentials.password === 'valid_password'){
                            this.valid = true;
                        }
                        commit(this.valid);
                    }
                    get canLogin() { return this.valid; }
                    get userProfile() { return { name: "John Doe" }; }
                }
                """
        )
    case .custom(let source):
        tenantConfig.providers.append(source)
    }
    let tenant = Tenant(
            name: tenantName ?? "Test Tenant",
            config: tenantConfig
    )
    EntityStorage.shared.tenants.insert(tenant)
    return tenant
}

/// Generate a set of Tenants and Clients
/// The client do not have a secret!
///
/// - Parameter clientIdent: A UUID that will associate to the client
/// - Parameter script: With test scripts should be uses (Select by artist names)
/// - Parameter scopes: Extra scopes for the clients | default to `*`
func generateTestClient(
        uuid clientIdent: UUID,
        script: TestTenantScripts? = .frodoBaker,
        scopes: [String]? = nil,
        referrers: [String]? = []
) {
    EntityStorage.shared.tenants.removeAll()
    EntityStorage.shared.clients.removeAll()
    let tenant = createTenant(script: script ?? .frodoBaker)

    let client = Client(
            name: "Test Client",
            config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: ["http://localhost:?([0-9]+)?", "http://example.com"],
                    scopes: scopes ?? ["*"],
                    referrers: referrers ?? []
            )
    )
    EntityStorage.shared.clients = [client]
}

func generateTestClient(
        uuid clientIdent: UUID,
        includeGrantTypes: [GrantTypes],
        script: TestTenantScripts? = .frodoBaker,
        scopes: [String]? = nil,
        referrers: [String]? = []
) {
    EntityStorage.shared.tenants.removeAll()
    EntityStorage.shared.clients.removeAll()

    let tenant = createTenant(
            script: script ?? .frodoBaker,
            interceptor: TenantInterceptorSettings(
                    enabled: includeGrantTypes.contains(where: { $0 == .interceptor }),
                    domain: "localhost.localdomain"
            ),
            informations: TenantInformations(
                    imprint_url: "https://localhost.localdomain/imprint",
                    privacy_url: "https://localhost.localdomain/privacy",
                    register_url: "https://localhost.localdomain/register"
            ),
            templates: TenantTemplatesSettings(
                    access_key_id: "testID",
                    secret_access_key: "testKey",
                    bucket: "testBucket",
                    host: "s3.localhost",
                    path: "test",
                    region: "test-region-42"
            )
    )

    let client = Client(
            name: "Test Client",
            config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: ["http://localhost:9090", "http://example.com", "localhost"],
                    grant_types: includeGrantTypes.filter({ $0 != .interceptor }),
                    scopes: scopes ?? ["*"],
                    referrers: referrers ?? []
            )
    )
    EntityStorage.shared.clients = [client]
}

/// Generate a set of Tenants and Clients
/// The client do not have a secret!
///
/// - Parameter clientIdent: A UUID that will associate to the client
/// - Parameter secret: Client secret to use
/// - Parameter script: With test scripts should be uses (Select by artist names)
/// - Parameter scopes: Extra scopes for the clients | default to `*`
func generateTestClientWithSecret(
        uuid clientIdent: UUID,
        secret: String,
        script: TestTenantScripts? = .frodoBaker,
        scopes: [String]? = nil,
        referrers: [String]? = []
) {
    EntityStorage.shared.tenants.removeAll()
    EntityStorage.shared.clients.removeAll()
    let tenant = createTenant(script: script ?? .frodoBaker)

    let client = Client(
            name: "Test Client",
            config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: ["http://localhost:?([0-9]+)?/?", "http://example.com"],
                    scopes: scopes ?? ["*"],
                    referrers: referrers ?? [],
                    secret: secret
            )
    )
    EntityStorage.shared.clients = [client]
}

func generateTestClientWithSecret(
        uuid clientIdent: UUID,
        includeGrantTypes: [GrantTypes],
        secret: String,
        script: TestTenantScripts? = .frodoBaker,
        scopes: [String]? = nil,
        referrers: [String]? = []
) {
    EntityStorage.shared.tenants.removeAll()
    EntityStorage.shared.clients.removeAll()
    let tenant = createTenant(
            script: script ?? .frodoBaker,
            interceptor: .init(
                    enabled: includeGrantTypes.contains(where: { $0 == .interceptor }),
                    domain: "localhost"
            )
    )

    let client = Client(
            name: "Test Client",
            config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: ["http://localhost:9090", "http://example.com"],
                    grant_types: includeGrantTypes.filter({ $0 != .interceptor }),
                    scopes: scopes ?? ["*"],
                    referrers: referrers ?? [],
                    secret: secret
            )
    )
    EntityStorage.shared.clients = [client]
}

/// Generate a set of Tenants and Clients
/// The client do not have a secret!
///
/// - Parameter clientIdents: A list of UUID that will associate to the clients
/// - Parameter script: With test scripts should be uses (Select by artist names)
/// - Parameter scopes: Extra scopes for the clients | default to `*`
func generateTestClientsWithMultipleTenants(
        uuids clientIdents: [UUID],
        script: TestTenantScripts? = .frodoBaker,
        scopes: [String]? = nil,
        referrers: [String]? = [],
        grant_types: [GrantTypes]? = [.authorization_code, .refresh_token]
) {
    EntityStorage.shared.tenants.removeAll()
    EntityStorage.shared.clients.removeAll()

    var i = 0
    clientIdents.forEach { clientIdent in
        i += 1
        let tenant = createTenant(
                script: script ?? .frodoBaker,
                name: "Test Tenant [\(i)] \(clientIdent)",
                hosts: ["127.0.0.\(i)"]
        )
        // Tenants.insert(tenant)
        EntityStorage.shared.clients.append(
                Client(
                        name: "Test Client \(clientIdent)",
                        config: ClientSpec(
                                ident: clientIdent,
                                tenantname: tenant.name,
                                redirect_urls: ["http://localhost:?([0-9]+)?", "http://example.com"],
                                grant_types: grant_types,
                                scopes: scopes ?? ["*"],
                                referrers: referrers ?? []
                        )
                )
        )
    }
}

/// Returns a valid authorisation token
///
/// - Parameter tenant: Tenant for the authorisation is for
/// - Parameter app: Vapor application
/// - Parameter date: Current date
/// - Returns: A valid bearer token
/// - Throws: Fatal error on errors
func validAuthorisation(
        for tenant: Tenant,
        in app: Application,
        now date: Date? = Date()
) throws -> BearerAuthorization {
    let calendar = Calendar.current
    guard let expirationDate = calendar.date(
            byAdding: .day,
            value: Constants.COOKIE.EXPIRATION_DAYS,
            to: date ?? Date())
    else {
        XCTFail("expirationDate can not be set")
        throw "Date failed"
    }
    let payload = Payload(
            subject: "test",
            expiration: .init(value: expirationDate),
            tenant: tenant.name,
            role: "default",
            user: "holger@mimimi.org"
    )
    let token = try app.jwt.signers.sign(payload)
    return BearerAuthorization(token: token)
}

/// Helper function to get a valid token
func getToken(app: Application, for code: String, appIdent testAppIdent: UUID) throws -> TokenResponse {
    let response = try app.sendRequest(.POST, "/token", beforeRequest: { req in
        let tokenRequest = CodeTokenRequest(
                grant_type: .authorization_code,
                client_id: testAppIdent.uuidString,
                client_secret: nil,
                scope: nil,
                code: Code(value: code).value
        )
        try req.content.encode(tokenRequest, as: .json)
        req.headers.contentType = .json
    })
    XCTAssertEqual(response.status, .ok)
    return try response.content.decode(TokenResponse.self)
}

/// Helper function to get a valid code with a client without secrets
func getCode(
        application app: Application,
        clientUUID testAppIdent: UUID,
        challenge: String,
        method: CodeChallengeMethod
) throws -> String {
    // get the tenant to save the id into the Payload
    guard let tenant: Tenant = EntityStorage.shared.clients.first(
            where: { $0.config.ident == testAppIdent }
    )?.config.tenant
    else {
        XCTFail("No tenant in client")
        throw TestError.abort
    }

    let url = "authorize"
            + "?response_type=code"
            + "&client_id=\(testAppIdent.uuidString)"
            + "&redirect_uri=http://localhost/"
            + "&scope=test"
            + "&state=123"
            + "&code_challenge=\(challenge)"
            + "&code_challenge_method=\(method.rawValue)"
    let response = try app.sendRequest(.GET, url, beforeRequest: { req in
        req.headers.bearerAuthorization = try validAuthorisation(for: tenant, in: app)
    })

    // check status
    XCTAssertEqual(response.status, .seeOther)

    let contentLength = response.headers["content-length"].first
    XCTAssertEqual(contentLength, "0")

    // check location
    let location = response.headers["location"].first
    XCTAssertContains(location, "http://localhost/?code=")
    let locationParts = location?.components(separatedBy: "?")
    let parameters = locationParts?[1].components(separatedBy: "&")
    let codeParameter = parameters?.filter({ $0.contains("code=") })
    let codeParameterPair = codeParameter?.first?.components(separatedBy: "=")

    guard let codeValue = codeParameterPair?[1] else {
        XCTFail("No code found")
        throw TestError.abort
    }

    // check code requirements
    XCTAssertEqual(codeValue.count, 16)
    return codeValue
}

func authorisationCodeGrantFlow(
        app: Application,
        clientIdent testAppIdent: UUID,
        scopes: [String]? = nil
) async throws -> String {
    let scopeFragment = scopes?.count ?? 0 > 0 ? "&scope=\(scopes?.joined(separator: ",") ?? "")" : ""

    // 1. Request Code
    // -----------------------------------
    let state = "rii4EPh5"
    let testServerAddress = "http://\(app.http.server.configuration.hostname):\(app.http.server.configuration.port)"
    let authorizeUrl = "/authorize"
            + "?response_type=code"
            + "&client_id=\(testAppIdent.uuidString)"
            + "&redirect_uri=http://localhost:9090"
            + "&scope=test"
            + "&state=\(state)\(scopeFragment)"
    let locationString = "\(testServerAddress)\(authorizeUrl.replacingOccurrences(of: "&", with: "&amp;"))"
    let responseAuthorize = try await app.sendRequest(
            .GET,
            authorizeUrl,
            headers: ["Content-Type": "application/json"]
    )

    XCTAssertEqual(responseAuthorize.status, .unauthorized)
    XCTAssertContains(responseAuthorize.body.string, "<body")
    XCTAssertContains(responseAuthorize.body.string, "</html>")
    XCTAssertContains(responseAuthorize.body.string, "login")

    // 2. Login
    // -----------------------------------
    let responseLoginSubmission = try app.sendRequest(.POST, "/login", beforeRequest: ({ req in
        req.headers = ["Content-Type": "application/x-www-form-urlencoded"]
        // fill the form
        try req.content.encode(LoginForm(
                username: "valid_user",
                password: "valid_password",
                location: locationString,
                scope: scopes?.joined(separator: " ") ?? ""
        ))
    }))
    XCTAssertEqual(responseLoginSubmission.status, .seeOther)

    var ssoCookie: HTTPCookies.Value?
    guard let cookie = responseLoginSubmission.headers.setCookie?[Constants.COOKIE.NAME] else {
        XCTFail("No set cookie header")
        throw Abort(.badRequest)
    }
    ssoCookie = cookie

    guard let location = responseLoginSubmission.headers.first(name: "location") else {
        XCTFail("No location header")
        throw Abort(.badRequest)
    }

    let loginResponseTypeGroups = try location.groups(regex: "response_type=([a-z]+)")
    let loginResponseType = loginResponseTypeGroups[1]
    XCTAssertEqual(loginResponseType, "code")

    let stateGroups = try location.groups(regex: "state=([a-zA-Z0-9]+)")
    let loginResponseState = stateGroups[1]
    XCTAssertEqual(loginResponseState, state)

    // 3. follow the redirect
    // -----------------------------------
    let redirectLocation = location
            .replacingOccurrences(of: testServerAddress, with: "")
            .replacingOccurrences(of: "&amp;", with: "&")

    guard let ssoCookie else {
        throw TestError.fail(withError: "No sso cookie found.")
    }
    let responseLoginRedirect = try await app.sendRequest(
            .GET,
            redirectLocation,
            headers: [
                "Cookie": ssoCookie.serialize(name: Constants.COOKIE.NAME)
            ]
    )

    // 4. Get the second redirect with the code
    // -----------------------------------
    guard let location = responseLoginRedirect.headers.first(name: "location") else {
        XCTFail("No location header in redirect")
        throw Abort(.badRequest)
    }

    let codeGroups = try location.groups(regex: "code=([a-zA-Z0-9]+)")
    let code = codeGroups[1]
    XCTAssertGreaterThan(code.count, 0)

    let loginRedirectStateGroups = try location.groups(regex: "state=([a-zA-Z0-9]+)")
    let loginRedirectState = loginRedirectStateGroups[1]
    XCTAssertEqual(loginRedirectState, state)
    return code
}
