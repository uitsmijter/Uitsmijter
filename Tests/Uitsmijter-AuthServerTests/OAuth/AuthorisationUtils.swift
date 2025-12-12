import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

enum TestTenantScripts {
    case frodoBaker
    case johnDoe
    case juanPerez
    case ivanIvano
    case custom(String)
}

@MainActor
// swiftlint:disable:next function_body_length
fileprivate func createTenant(
    in storage: EntityStorage,
    script: TestTenantScripts,
    name tenantName: String? = nil, hosts: [String]? = [
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
    storage.tenants.insert(tenant)
    return tenant
}

/// Generate a set of Tenants and Clients
/// The client do not have a secret!
///
/// - Parameter clientIdent: A UUID that will associate to the client
/// - Parameter script: With test scripts should be uses (Select by artist names)
/// - Parameter scopes: Extra scopes for the clients | default to `*`
/// - Parameter grantTypes: Grant types to configure for the client | default to authorization_code and refresh_token
@MainActor
func generateTestClient(
    in storage: EntityStorage,
    uuid clientIdent: UUID,
    script: TestTenantScripts? = .frodoBaker,
    scopes: [String]? = nil,
    referrers: [String]? = [],
    grantTypes: [GrantTypes]? = [.authorization_code, .refresh_token]
) {
    storage.tenants.removeAll()
    storage.clients.removeAll()
    let tenant = createTenant(in: storage, script: script ?? .frodoBaker)

    let client = Client(
        name: "Test Client",
        config: ClientSpec(
            ident: clientIdent,
            tenantname: tenant.name,
            redirect_urls: ["http://localhost:?([0-9]+)?", "http://example.com"],
            grant_types: grantTypes?.map { $0.rawValue },
            scopes: scopes ?? ["*"],
            referrers: referrers ?? []
        )
    )
    storage.clients = [client]
}

@MainActor
func generateTestClient(
    in storage: EntityStorage,
    uuid clientIdent: UUID,
    includeGrantTypes: [GrantTypes],
    script: TestTenantScripts? = .frodoBaker,
    scopes: [String]? = nil,
    referrers: [String]? = []
) {
    storage.tenants.removeAll()
    storage.clients.removeAll()

    let tenant = createTenant(in: storage,
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
            grant_types: includeGrantTypes.filter({ $0 != .interceptor }).map { $0.rawValue },
            scopes: scopes ?? ["*"],
            referrers: referrers ?? []
        )
    )
    storage.clients = [client]
}

/// Generate a set of Tenants and Clients
/// The client do not have a secret!
///
/// - Parameter clientIdent: A UUID that will associate to the client
/// - Parameter secret: Client secret to use
/// - Parameter script: With test scripts should be uses (Select by artist names)
/// - Parameter scopes: Extra scopes for the clients | default to `*`
/// - Parameter grantTypes: Grant types to configure for the client | default to authorization_code and refresh_token
@MainActor
func generateTestClientWithSecret(
    in storage: EntityStorage,
    uuid clientIdent: UUID,
    secret: String,
    script: TestTenantScripts? = .frodoBaker,
    scopes: [String]? = nil,
    referrers: [String]? = [],
    grantTypes: [GrantTypes]? = [.authorization_code, .refresh_token]
) {
    storage.tenants.removeAll()
    storage.clients.removeAll()
    let tenant = createTenant(in: storage, script: script ?? .frodoBaker)

    let client = Client(
        name: "Test Client",
        config: ClientSpec(
            ident: clientIdent,
            tenantname: tenant.name,
            redirect_urls: ["http://localhost:?([0-9]+)?/?", "http://example.com"],
            grant_types: grantTypes?.map { $0.rawValue },
            scopes: scopes ?? ["*"],
            referrers: referrers ?? [],
            secret: secret
        )
    )
    storage.clients = [client]
}

@MainActor
func generateTestClientWithSecret(
    in storage: EntityStorage,
    uuid clientIdent: UUID,
    includeGrantTypes: [GrantTypes],
    secret: String,
    script: TestTenantScripts? = .frodoBaker,
    scopes: [String]? = nil,
    referrers: [String]? = []
) {
    storage.tenants.removeAll()
    storage.clients.removeAll()
    let tenant = createTenant(in: storage,
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
            grant_types: includeGrantTypes.filter({ $0 != .interceptor }).map { $0.rawValue },
            scopes: scopes ?? ["*"],
            referrers: referrers ?? [],
            secret: secret
        )
    )
    storage.clients = [client]
}

/// Generate a set of Tenants and Clients
/// The client do not have a secret!
///
/// - Parameter clientIdents: A list of UUID that will associate to the clients
/// - Parameter script: With test scripts should be uses (Select by artist names)
/// - Parameter scopes: Extra scopes for the clients | default to `*`
/// - Parameter grantTypes: Grant types to configure for the client | default to authorization_code and refresh_token
@MainActor
func generateTestClientsWithMultipleTenants(
    in storage: EntityStorage,
    uuids clientIdents: [UUID],
    script: TestTenantScripts? = .frodoBaker,
    scopes: [String]? = nil,
    referrers: [String]? = [],
    grantTypes: [GrantTypes]? = [.authorization_code, .refresh_token]
) {
    storage.tenants.removeAll()
    storage.clients.removeAll()

    var i = 0
    clientIdents.forEach { clientIdent in
        i += 1
        let tenant = createTenant(in: storage,
            script: script ?? .frodoBaker,
            name: "Test Tenant [\(i)] \(clientIdent)",
            hosts: ["127.0.0.\(i)"]
        )
        // Tenants.insert(tenant)
        storage.clients.append(
            Client(
                name: "Test Client \(clientIdent)",
                config: ClientSpec(
                    ident: clientIdent,
                    tenantname: tenant.name,
                    redirect_urls: ["http://localhost:?([0-9]+)?", "http://example.com"],
                    grant_types: grantTypes?.map { $0.rawValue },
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
) async throws -> BearerAuthorization {
    let calendar = Calendar.current
    guard let expirationDate = calendar.date(
            byAdding: .day,
            value: Constants.COOKIE.EXPIRATION_DAYS,
            to: date ?? Date())
    else {
        Issue.record("expirationDate can not be set")
        throw "Date failed"
    }
    let payload = Payload(
        issuer: IssuerClaim(value: "https://test.example.com"),
        subject: "test",
        audience: AudienceClaim(value: "test-client"),
        expiration: .init(value: expirationDate),
        issuedAt: IssuedAtClaim(value: Date()),
        authTime: AuthTimeClaim(value: Date()),
        tenant: tenant.name,
        role: "default",
        user: "holger@mimimi.org",
        scope: [], // TODO insert correct scope values
    )
    let (tokenString, _) = try await SignerManager.shared.sign(payload)
    return BearerAuthorization(token: tokenString)
}

/// Helper function to get a valid token
func getToken(app: Application, for code: String, appIdent testAppIdent: UUID) async throws -> TokenResponse {
    let response = try await app.sendRequest(.POST, "/token", beforeRequest: { @Sendable req async throws in
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
    #expect(response.status == .ok)
    let tokenResponse = try response.content.decode(TokenResponse.self)
    return tokenResponse
}

/// Helper function to get a valid code with a client without secrets
func getCode(
    in storage: EntityStorage,
    application app: Application,
    clientUUID testAppIdent: UUID,
    challenge: String,
    method: CodeChallengeMethod,
    scopes: [String]? = ["test"]
) async throws -> String {
    // get the tenant to save the id into the Payload
    guard let tenant: Tenant = await storage.clients.first(
        where: { $0.config.ident == testAppIdent }
    )?.config.tenant(in: app.entityStorage)
    else {
        Issue.record("No tenant in client")
        throw TestError.abort
    }
    let scopeString = scopes!.joined(separator: "+")
    
    let url = "authorize"
        + "?response_type=code"
        + "&client_id=\(testAppIdent.uuidString)"
        + "&redirect_uri=http://localhost/"
        + "&scope=\(scopeString)"
        + "&state=123"
        + "&code_challenge=\(challenge)"
        + "&code_challenge_method=\(method.rawValue)"
    let response = try await app.sendRequest(.GET, url, beforeRequest: { @Sendable req async throws in
        req.headers.add(name: "referer", value: "http://example.com")
        req.headers.bearerAuthorization = try await validAuthorisation(for: tenant, in: app)
    })

    // check status
    #expect(response.status == .seeOther)

    let contentLength = response.headers["content-length"].first
    #expect(contentLength == "0")

    // check location
    let location = response.headers["location"].first
    #expect(location?.contains("http://localhost/?code=") == true)
    let locationParts = location?.components(separatedBy: "?")
    let parameters = locationParts?[1].components(separatedBy: "&")
    let codeParameter = parameters?.filter({ $0.contains("code=") })
    let codeParameterPair = codeParameter?.first?.components(separatedBy: "=")

    guard let codeValue = codeParameterPair?[1] else {
        Issue.record("No code found")
        throw TestError.abort
    }

    // check code requirements
    #expect(codeValue.count == 16)
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

    #expect(responseAuthorize.status == .unauthorized)
    #expect(responseAuthorize.body.string.contains("<body"))
    #expect(responseAuthorize.body.string.contains("</html>"))
    #expect(responseAuthorize.body.string.contains("login"))

    // 2. Login
    // -----------------------------------
    let responseLoginSubmission = try await app.sendRequest(.POST, "/login", beforeRequest: ({ req async throws in
        req.headers = ["Content-Type": "application/x-www-form-urlencoded"]
        // fill the form
        try req.content.encode(LoginForm(
            username: "valid_user",
            password: "valid_password",
            location: locationString,
            scope: scopes?.joined(separator: " ") ?? ""
        ))
    }))
    #expect(responseLoginSubmission.status == .seeOther)

    var ssoCookie: HTTPCookies.Value?
    guard let cookie = responseLoginSubmission.headers.setCookie?[Constants.COOKIE.NAME] else {
        Issue.record("No set cookie header")
        throw Abort(.badRequest)
    }
    ssoCookie = cookie

    guard let location = responseLoginSubmission.headers.first(name: "location") else {
        Issue.record("No location header")
        throw Abort(.badRequest)
    }

    let loginResponseTypeGroups = try location.groups(regex: "response_type=([a-z]+)")
    let loginResponseType = loginResponseTypeGroups[1]
    #expect(loginResponseType == "code")

    let stateGroups = try location.groups(regex: "state=([a-zA-Z0-9]+)")
    let loginResponseState = stateGroups[1]
    #expect(loginResponseState == state)

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
        Issue.record("No location header in redirect")
        throw Abort(.badRequest)
    }

    let codeGroups = try location.groups(regex: "code=([a-zA-Z0-9]+)")
    let code = codeGroups[1]
    #expect(!code.isEmpty)

    let loginRedirectStateGroups = try location.groups(regex: "state=([a-zA-Z0-9]+)")
    let loginRedirectState = loginRedirectStateGroups[1]
    #expect(loginRedirectState == state)
    return code
}
