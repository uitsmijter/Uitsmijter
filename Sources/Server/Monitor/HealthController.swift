import Foundation
import Vapor

final class HealthController: RouteCollection {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        let health = routes.grouped("health")
        health.get(use: isHealthy)
        health.get("ready", use: isReady)
    }

    /// Is this service active?
    func isHealthy(_ req: Request) async throws -> HTTPStatus {
        // check AuthCodeStorage
        if let authCodeStorage = req.application.authCodeStorage {
            if authCodeStorage.isHealthy() == false {
                Log.critical("AuthCodeStorage is not healthy", request: req)
                return .internalServerError
            }
        }
        return .noContent
    }

    /// Is this service ready to start?
    func isReady(_ req: Request) async throws -> HTTPStatus {
        if req.application.authCodeStorage == nil {
            return .expectationFailed
        }
        return try await isHealthy(req)
    }
}
