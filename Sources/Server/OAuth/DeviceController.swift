import Foundation
import Vapor

struct DeviceController: RouteCollection, OAuthControllerProtocol {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("device")
        auth.post(use: requestDevice)
    }

    func requestDevice(req: Request) async throws -> DeviceResponse {
        let deviceRequest = try req.content.decode(DeviceRequest.self)
        Log.info("""
                 Request Device 
                 client: \(deviceRequest.client_id)
                 """, request: req)

        let client = try client(for: deviceRequest)
        

        if client.config.grant_types?.contains(where: { $0 == deviceRequest.grant_type }) != true {
            let grantTypesDescriptions: String? = client.config.grant_types.map({ $0.description })

            Log.error(
                    """
                    Device request grant type '\\(deviceRequest.grant_type)' is not allowed
                    by client \(client.name): [\(grantTypesDescriptions ?? "no_grant_types")]
                    """, request: req)

            metricsOAuthFailure?.inc(1, [
                ("tenant", client.config.tenantname),
                ("client", client.name),
                ("grant_type", deviceRequest.grant_type.rawValue),
                ("reason", "UNSUPPORTED_GRANT_TYPE")
            ])
            throw Abort(.badRequest, reason: "ERROR.UNSUPPORTED_GRANT_TYPE")
        }

        do {
            guard let tenant = client.config.tenant else {
                throw ClientError.clientHasNoTenant
            }

            let deviceResponse = try await deviceTokenGrantTypeRequestHandler(
                    for: tenant,
                    on: req,
                    scopes: allowedScopes(on: client, for: deviceRequest)
            )
            metricsOAuthSuccess?.inc(1, [
                ("tenant", tenant.name),
                ("client", client.name),
                ("grant_type", deviceRequest.grant_type.rawValue)
            ])

            return deviceResponse
        } catch {
            metricsOAuthFailure?.inc(1, [
                ("tenant", client.config.tenantname),
                ("client", client.name),
                ("grant_type", deviceRequest.grant_type.rawValue),
                ("reason", error.localizedDescription)
            ])
            throw error
        }
    }

     private func deviceTokenGrantTypeRequestHandler(
            for tenant: Tenant,
            on req: Request,
            scopes: [String]
    ) async throws -> DeviceResponse {
        
        guard let authCodeStorage = req.application.authCodeStorage else {
            throw Abort(.insufficientStorage, reason: "ERRORS.CODE_STORAGE_AVAILABILITY")
        }

        let userCode = String.random(length: 8)

        let session = AuthSession(
            type: .code,
            state: "",
            code: Code(value: userCode),
            scopes: [],
            payload: nil,
            redirect: "",
            ttl: 60
        )

        try authCodeStorage.set(authSession: session)
        
        Log.info(
                "Device code request succeeded \(session.payload?.user ?? "-") with scopes: \(scopes.joined(separator: ","))",
                request: req
        )

        return DeviceResponse(
            device_code: "",
            verification_uri: URL(string: "String")!,
            user_code: userCode,
            expires_in: 60,
            interval: 5
        )
    }
}
