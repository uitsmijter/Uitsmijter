import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

/// Shared ClientInfo for tests
@MainActor
enum SharedClientInfo {

    /// ClientInfo for interceptor mode
    static func clientInfo(on request: Request) -> ClientInfo {
        ClientInfo(
            mode: .interceptor,
            requested: ClientInfoRequest(
                scheme: request.url.scheme ?? "http",
                host: request.headers.first(name: "X-Forwarded-Host") ?? "",
                uri: request.url.path
            ),
            referer: nil,
            responsibleDomain: request.headers.first(name: "X-Forwarded-Host") ?? "",
            serviceUrl: "localhost",
            tenant: Tenant.find(
                in: request.application.entityStorage,
                forHost: request.headers.first(name: "X-Forwarded-Host") ?? "_ERROR_"
            ),
            client: nil,
            expired: nil,
            subject: nil,
            validPayload: nil
        )
    }
}
