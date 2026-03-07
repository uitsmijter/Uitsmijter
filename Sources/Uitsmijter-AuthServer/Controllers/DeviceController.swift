import Foundation
import Vapor
import Logger

/// Controller for the Device Authorization endpoint (RFC 8628, Section 3.1–3.2).
///
/// Clients call `POST /oauth/device_authorization` to initiate a device authorization flow.
/// The response contains a `device_code` for polling the token endpoint and a short
/// `user_code` that the user enters at the verification URI on another device.
///
/// ## Flow
///
/// 1. Device posts `client_id` (and optional `scope`) to this endpoint.
/// 2. Server returns `device_code`, `user_code`, `verification_uri`, `expires_in`, `interval`.
/// 3. Device displays `user_code` and `verification_uri` to the user.
/// 4. Device polls `POST /token` with `grant_type=device_code` at `interval`-second intervals.
/// 5. User visits `verification_uri`, logs in, and enters `user_code`.
/// 6. Next poll returns the access token.
///
/// - SeeAlso: ``DeviceAuthorizationRequest``, ``DeviceAuthorizationResponse``
struct DeviceController: RouteCollection, OAuthControllerProtocol {

    func boot(routes: RoutesBuilder) throws {
        let oauth = routes.grouped("oauth")
        oauth.post("device_authorization", use: { @Sendable (req: Request) async throws -> Response in
            try await self.authorize(req: req)
        })
    }

    // MARK: - Route Handler

    @Sendable func authorize(req: Request) async throws -> Response {
        let deviceRequest = try req.content.decode(DeviceAuthorizationRequest.self)

        // Validate client
        let uitsmijterClient = try await client(for: deviceRequest, request: req)

        // Device grant must be configured for the client
        guard let grantConfig = uitsmijterClient.config.device_grant_config else {
            Log.error(
                "device_grant_config not configured for client \(deviceRequest.client_id)",
                requestId: req.id
            )
            throw Abort(.badRequest, reason: "ERRORS.DEVICE_GRANT_NOT_CONFIGURED")
        }

        // Client must explicitly allow device_code grant type
        let grantTypes = uitsmijterClient.config.grant_types ?? []
        guard grantTypes.contains(GrantTypes.device_code.rawValue) else {
            Log.error(
                "device_code grant not enabled for client \(deviceRequest.client_id)",
                requestId: req.id
            )
            throw Abort(.badRequest, reason: "ERRORS.GRANT_TYPE_NOT_SUPPORTED")
        }

        let expiresIn = grantConfig.expires_in ?? 1800
        let interval = grantConfig.interval ?? 5

        // Determine verification URI
        let verificationUri: String
        if let configuredUri = grantConfig.verification_uri {
            verificationUri = configuredUri
        } else {
            let scheme = req.headers.first(name: "X-Forwarded-Proto")
                ?? (Constants.TOKEN.isSecure ? "https" : "http")
            let host = req.headers.first(name: "X-Forwarded-Host")
                ?? req.headers.first(name: "Host")
                ?? Constants.PUBLIC_DOMAIN
            verificationUri = "\(scheme)://\(host)/activate"
        }

        // Generate device_code (opaque, used by the device to poll)
        let deviceCode = String.random(length: 32)

        // Generate user_code (short, human-friendly: XXXX-XXXX)
        let userCodeCharset = String.RandomCharacterSet.custom("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let userCode = try await generateUniqueUserCode(
            charset: userCodeCharset,
            storage: req.application.authCodeStorage
        )

        // Parse requested scopes
        let requestedScopes = (deviceRequest.scope ?? "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        // Store device session
        guard let storage = req.application.authCodeStorage else {
            throw Abort(.insufficientStorage, reason: "ERRORS.CODE_STORAGE_AVAILABILITY")
        }

        let session = AuthSession.device(DeviceSession(
            clientId: uitsmijterClient.config.ident.uuidString,
            deviceCode: Code(value: deviceCode),
            userCode: userCode,
            scopes: requestedScopes,
            payload: nil,
            status: .pending,
            ttl: Int64(expiresIn)
        ))
        try await storage.set(authSession: session)

        Prometheus.main.deviceFlowInitiation?.inc()
        Log.info(
            "Device flow initiated for client \(deviceRequest.client_id), userCode: \(userCode)",
            requestId: req.id
        )

        let responseBody = DeviceAuthorizationResponse(
            device_code: deviceCode,
            user_code: userCode,
            verification_uri: verificationUri,
            expires_in: expiresIn,
            interval: interval
        )
        return try await responseBody.encodeResponse(status: HTTPStatus.ok, for: req).get()
    }

    // MARK: - Private

    /// Generates a unique XXXX-XXXX user code that is not already in use.
    private func generateUniqueUserCode(
        charset: String.RandomCharacterSet,
        storage: AuthCodeStorage?
    ) async throws -> String {
        for _ in 0..<10 {
            let raw = String.random(length: 8, of: charset)
            let code = "\(raw.prefix(4))-\(raw.suffix(4))"
            if await storage?.getDevice(byUserCode: code) == nil {
                return code
            }
        }
        throw Abort(.internalServerError, reason: "ERRORS.USER_CODE_GENERATION_FAILED")
    }
}
