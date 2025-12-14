import Foundation
import Vapor
import Logger

protocol OAuthControllerProtocol {
}

extension OAuthControllerProtocol {

    /// get the client for the auth request
    ///
    /// - Parameters:
    ///   - objectWithClientId: Request type with a client_id, eg. AuthRequestProtocol
    ///   - request: The current request
    /// - Returns: A Client
    /// - Throws: if the client is not found
    ///
    func client(for objectWithClientId: ClientIdProtocol, request: Request) async throws -> UitsmijterClient {
        let clientId = objectWithClientId.client_id
        let foundClient = await UitsmijterClient.find(in: request.application.entityStorage, clientId: clientId)
        guard let client = foundClient else {
            Log.error("Unable to find client \(objectWithClientId.client_id)")
            throw Abort(.notFound, reason: "ERRORS.NO_CLIENT")
        }
        return client
    }

    /// Returns a subset of the requested scopes that are allowed by the client
    ///
    /// - Parameters:
    ///   - client: The client on which to operate
    ///   - objectWithScopes: Request type of AuthRequestProtocol
    /// - Returns: A list of scopes that are requested and that are allowed by the client
    ///
    ///
    func allowedScopes(on client: UitsmijterClient, for scopes: [String]) -> [String] {
        allowedScopes(on: client.config.scopes ?? [] as [String], for: scopes)
    }

    func allowedScopes(on allowedScopes: [String], for scopes: [String]) -> [String] {
        // checked scopes only
        // (objectWithScopes.scope ?? "").components(separatedBy: .whitespacesAndNewlines)
        scopes.filter { inputScope in
            allowedScopes.contains { clientScope in
                var _clientScope = clientScope
                // Allowed are Asterisks - reformat into regex
                if clientScope.contains("*") {
                    _clientScope = "^\(clientScope.replacingOccurrences(of: "*", with: ".+"))$"
                } else {
                    _clientScope = "^\(clientScope)$"
                }
                let groupsMatched = (try? inputScope.groups(regex: _clientScope).count) ?? 0
                if groupsMatched > 0 {
                    return true
                }
                return false
            }
        }
    }
}
