import Foundation
import Vapor

protocol OAuthControllerProtocol {
}

extension OAuthControllerProtocol {

    /// get the client for the auth request
    ///
    /// - Parameter objectWithClientId: Request type with a client_id, eg. AuthRequestProtocol
    /// - Returns: A Client
    /// - Throws: if the client is not found
    ///
    func client(for objectWithClientId: ClientIdProtocol) throws -> Client {
        guard let client = Client.find(id: objectWithClientId.client_id) else {
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
    func allowedScopes(on client: Client, for objectWithScopes: ScopesProtocol) -> [String] {
        // checked scopes only
        (objectWithScopes.scope ?? "").components(separatedBy: .whitespacesAndNewlines).filter { inputScope in
            client.config.scopes?.contains { clientScope in
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
            } ?? false
        }
    }
}
