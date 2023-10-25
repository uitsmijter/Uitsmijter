import Foundation
import Vapor

struct RequestClientParser {

    let client: Client

    /// Errors that can occur
    enum RequestClientParserErrors: Error {
        case INVALID_UUID
        case NO_DATA
        case CLIENT_NOT_FOUND(UUID)
    }

    init(on request: Request) throws {
        // get from body first
        if let clientParameter: ClientIdParameter = try? request.content.decode(ClientIdParameter.self) {
            let client_id = try RequestClientParser.getClientIdent(uuidString: clientParameter.client_id)
            guard let _client = Client.find(id: client_id.uuidString) else {
                Log.error("CLIENT_NOT_FOUND: \(client_id)", request: request)
                throw RequestClientParserErrors.CLIENT_NOT_FOUND(client_id)
            }
            client = _client
            return
        } else {
            // then from query
            if let clientResult: ClientIdParameter = try? request.query.decode(ClientIdParameter.self) {
                let client_id = try RequestClientParser.getClientIdent(uuidString: clientResult.client_id)
                guard let _client = Client.find(id: client_id.uuidString) else {
                    Log.error("CLIENT_NOT_FOUND: \(client_id)", request: request)
                    throw RequestClientParserErrors.CLIENT_NOT_FOUND(client_id)
                }
                client = _client
                return
            }
        }
        throw RequestClientParserErrors.NO_DATA
    }

    // MARK: - Private Helpers

    private static func getClientIdent(uuidString: String) throws -> UUID {
        guard let ident = UUID(uuidString: uuidString) else {
            Log.error("Can't construct a UUID out of the clients id: '\(uuidString)'")
            throw RequestClientParserErrors.INVALID_UUID
        }
        return ident
    }
}
