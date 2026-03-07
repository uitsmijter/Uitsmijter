import Foundation
import Vapor
import JWT
import Logger

/// Template context for the device activation page.
struct ActivatePageProperties: Encodable, Sendable {
    let title: String
    var error: String?
    var success: Bool
    var userCode: String?
    var tenant: Tenant?

    init(
        title: String = "Activate Device",
        error: String? = nil,
        success: Bool = false,
        userCode: String? = nil,
        tenant: Tenant? = nil
    ) {
        self.title = title
        self.error = error
        self.success = success
        self.userCode = userCode
        self.tenant = tenant
    }
}

/// Controller for the device activation endpoint (RFC 8628, Section 3.3).
///
/// Users visit `GET /activate` on their browser, enter the `user_code` shown on
/// the device, and authenticate. On success the device session is marked as
/// `authorized` so the device's next poll at `POST /token` returns the access token.
///
/// ## Route Registration
///
/// - `GET /activate` — displays the activation form
/// - `POST /activate` — processes user_code + credentials
struct ActivateController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let activate = routes.grouped("activate")
        activate.get(use: { @Sendable (req: Request) async throws -> Response in
            try await self.getActivate(req: req)
        })
        activate.post(use: { @Sendable (req: Request) async throws -> Response in
            try await self.doActivate(req: req)
        })
    }

    // MARK: - GET /activate

    @Sendable func getActivate(req: Request) async throws -> Response {
        let userCode: String? = try? req.query.get(at: "user_code")

        // If user_code is present and a valid JWT cookie exists, auto-authorize
        if let rawCode = userCode,
           let payload = try? await req.jwt.verify(as: Payload.self),
           (try? payload.expiration.verifyNotExpired(currentDate: Date())) != nil {

            let normalized = normalizeUserCode(rawCode)

            guard let storage = req.application.authCodeStorage else {
                return try await renderActivateView(req: req, status: .internalServerError, props: .init(
                    error: "ERRORS.STORAGE_UNAVAILABLE"
                ))
            }

            if let deviceSession = await storage.getDevice(byUserCode: normalized),
               case .device(let deviceData) = deviceSession,
               deviceData.status == .pending {
                try await storage.updateDevice(
                    deviceCode: deviceSession.codeValue,
                    newStatus: .authorized,
                    payload: payload,
                    lastPolledAt: nil
                )
                Prometheus.main.deviceFlowAuthorized?.inc()
                Log.info("Device authorized via cookie for userCode: \(normalized)", requestId: req.id)
                return try await renderActivateView(req: req, status: .ok, props: .init(success: true))
            }
        }

        return try await renderActivateView(req: req, status: .ok, props: .init(userCode: userCode))
    }

    // MARK: - POST /activate

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    @Sendable func doActivate(req: Request) async throws -> Response {
        guard let rawCode: String = try? req.content.get(at: "user_code"), !rawCode.isEmpty else {
            return try await renderActivateView(req: req, status: .badRequest, props: .init(
                error: "ACTIVATE.ERRORS.MISSING_CODE"
            ))
        }

        let normalized = normalizeUserCode(rawCode)

        guard let storage = req.application.authCodeStorage else {
            return try await renderActivateView(req: req, status: .internalServerError, props: .init(
                error: "ERRORS.STORAGE_UNAVAILABLE"
            ))
        }

        guard let deviceSession = await storage.getDevice(byUserCode: normalized) else {
            return try await renderActivateView(req: req, status: .badRequest, props: .init(
                error: "ACTIVATE.ERRORS.INVALID_CODE",
                userCode: rawCode
            ))
        }

        guard case .device(let deviceData) = deviceSession, deviceData.status == .pending else {
            return try await renderActivateView(req: req, status: .badRequest, props: .init(
                error: "ACTIVATE.ERRORS.CODE_ALREADY_USED",
                userCode: rawCode
            ))
        }

        // If the user already has a valid JWT cookie, authorize immediately without credentials
        if let payload = try? await req.jwt.verify(as: Payload.self),
           (try? payload.expiration.verifyNotExpired(currentDate: Date())) != nil {
            try await storage.updateDevice(
                deviceCode: deviceSession.codeValue,
                newStatus: .authorized,
                payload: payload,
                lastPolledAt: nil
            )
            Prometheus.main.deviceFlowAuthorized?.inc()
            Log.info("Device authorized via cookie for userCode: \(normalized)", requestId: req.id)
            return try await renderActivateView(req: req, status: .ok, props: .init(success: true))
        }

        // No cookie → authenticate with submitted credentials
        guard let username: String = try? req.content.get(at: "username"),
              let password: String = try? req.content.get(at: "password"),
              !username.isEmpty else {
            return try await renderActivateView(req: req, status: .badRequest, props: .init(
                error: "ACTIVATE.ERRORS.CREDENTIALS_REQUIRED",
                userCode: rawCode
            ))
        }

        // Find client and tenant from the device session
        guard let client = await Client.find(
            in: req.application.entityStorage,
            clientId: deviceData.clientId
        ) else {
            Log.error("Client \(deviceData.clientId) not found for device session", requestId: req.id)
            return try await renderActivateView(req: req, status: .badRequest, props: .init(
                error: "ACTIVATE.ERRORS.INVALID_CODE",
                userCode: rawCode
            ))
        }

        guard let tenant = await client.config.tenant(in: req.application.entityStorage) else {
            Log.error("Tenant not found for client \(deviceData.clientId)", requestId: req.id)
            return try await renderActivateView(req: req, status: .badRequest, props: .init(
                error: "ERRORS.NO_TENANT",
                userCode: rawCode
            ))
        }

        // Authenticate via JavaScript provider
        let providerInterpreter = JavaScriptProvider()
        try await providerInterpreter.loadProvider(
            script: tenant.config.providers.joined(separator: "\n")
        )
        try await providerInterpreter.start(
            class: .userLogin,
            arguments: JSInputCredentials(
                username: username,
                password: password,
                grantType: .device_code
            )
        )

        guard await providerInterpreter.canLogin() else {
            Log.info("Activate: cannot log in user \(username)", requestId: req.id)
            Prometheus.main.loginFailure?.inc()
            return try await renderActivateView(req: req, status: .forbidden, props: .init(
                error: "LOGIN.ERRORS.WRONG_CREDENTIALS",
                userCode: rawCode,
                tenant: tenant
            ))
        }

        // Build payload from provider results
        let providedSubject: SubjectProtocol = await providerInterpreter.getSubject(
            loginHandle: username
        )
        let profile = await providerInterpreter.getProfile()
        let role = await providerInterpreter.getRole()
        let providerScopes = await providerInterpreter.getScopes()

        let scheme = req.headers.first(name: "X-Forwarded-Proto")
            ?? (Constants.TOKEN.isSecure ? "https" : "http")
        let host = req.headers.first(name: "X-Forwarded-Host")
            ?? req.headers.first(name: "Host")
            ?? tenant.config.hosts.first
            ?? Constants.PUBLIC_DOMAIN
        let issuer = "\(scheme)://\(host)"

        let expirationDate = Calendar.current.date(
            byAdding: .day,
            value: Constants.COOKIE.EXPIRATION_DAYS,
            to: Date()
        ) ?? Date(timeIntervalSinceNow: Double(Constants.COOKIE.EXPIRATION_DAYS) * 86_400)

        let finalScopes = Array(Set(deviceData.scopes + providerScopes)).sorted()
        let now = Date()
        let payload = Payload(
            issuer: IssuerClaim(value: issuer),
            subject: providedSubject.subject,
            audience: AudienceClaim(value: deviceData.clientId),
            expiration: ExpirationClaim(value: expirationDate),
            issuedAt: IssuedAtClaim(value: now),
            authTime: AuthTimeClaim(value: now),
            tenant: tenant.name,
            responsibility: "",
            role: role,
            user: username,
            scope: finalScopes.joined(separator: " "),
            profile: profile
        )

        try await storage.updateDevice(
            deviceCode: deviceSession.codeValue,
            newStatus: .authorized,
            payload: payload,
            lastPolledAt: nil
        )

        Prometheus.main.deviceFlowAuthorized?.inc()
        Prometheus.main.loginSuccess?.inc()
        Log.info(
            "Device authorized for userCode: \(normalized) by user: \(username)",
            requestId: req.id
        )

        return try await renderActivateView(req: req, status: .ok, props: .init(
            success: true,
            tenant: tenant
        ))
    }

    // MARK: - Helpers

    private func normalizeUserCode(_ raw: String) -> String {
        let stripped = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        if stripped.count == 8 {
            return "\(stripped.prefix(4))-\(stripped.suffix(4))"
        }
        return raw.uppercased()
    }

    private func renderActivateView(
        req: Request,
        status: HTTPResponseStatus,
        props: ActivatePageProperties
    ) async throws -> Response {
        // Activate is a cross-tenant endpoint — it bypasses RequestClientMiddleware,
        // so clientInfo?.tenant is nil. Fall back to the default activate template
        // instead of the error template that Template.getPath would return for nil tenant.
        let templatePath = req.clientInfo?.tenant != nil
            ? Template.getPath(page: "activate", request: req)
            : "default/activate"
        return try await req.view.render(templatePath, props)
            .flatMap { $0.encodeResponse(status: status, for: req) }
            .get()
    }
}
