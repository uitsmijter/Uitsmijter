import Foundation
import Vapor
import Logger

// MARK: - Request Client Parser

/// Parses and validates client information from incoming requests.
///
/// This structure extracts the `client_id` parameter from either the request body
/// or query parameters, validates the UUID format, and looks up the corresponding
/// client in the entity storage.
///
/// ## Usage
///
/// ```swift
/// let parser = try RequestClientParser(on: request)
/// let client = parser.client
/// ```
///
/// ## Client ID Sources
///
/// The parser checks for `client_id` in the following order:
/// 1. Request body (POST parameters)
/// 2. Query parameters (GET parameters)
///
/// ## Validation
///
/// - Ensures `client_id` is a valid UUID format
/// - Verifies the client exists in entity storage
/// - Throws appropriate errors for missing or invalid clients
///
/// ## Error Handling
///
/// - ``RequestClientParserErrors/NO_DATA`` if no client_id found
/// - ``RequestClientParserErrors/INVALID_UUID`` if client_id is malformed
/// - ``RequestClientParserErrors/CLIENT_NOT_FOUND(_:)`` if client doesn't exist
///
/// ## Topics
///
/// ### Properties
/// - ``client``
///
/// ### Initialization
/// - ``init(on:)``
///
/// - SeeAlso: ``Client``
/// - SeeAlso: ``ClientIdParameter``
/// - SeeAlso: ``RequestClientParserErrors``
struct RequestClientParser {

    // MARK: - Properties

    /// The resolved client instance from entity storage.
    let client: UitsmijterClient

    // MARK: - Initialization

    /// Creates a new parser and resolves the client from the request.
    ///
    /// This initializer attempts to extract the `client_id` from either the request
    /// body or query parameters, validates it as a UUID, and looks up the client
    /// in the application's entity storage.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // From query parameter
    /// // GET /token?client_id=550e8400-e29b-41d4-a716-446655440000
    ///
    /// // From request body
    /// // POST /token
    /// // client_id=550e8400-e29b-41d4-a716-446655440000
    ///
    /// let parser = try RequestClientParser(on: request)
    /// print("Client: \(parser.client.name)")
    /// ```
    ///
    /// - Parameter request: The incoming HTTP request
    /// - Throws:
    ///   - ``RequestClientParserErrors/NO_DATA`` if no `client_id` is present
    ///   - ``RequestClientParserErrors/INVALID_UUID`` if `client_id` is not a valid UUID
    ///   - ``RequestClientParserErrors/CLIENT_NOT_FOUND(_:)`` if client doesn't exist
    ///
    /// - SeeAlso: ``ClientIdParameter``
    @MainActor
    init(on request: Request) throws {
        // get from body first
        if let clientParameter: ClientIdParameter = try? request.content.decode(ClientIdParameter.self) {
            let client_id = try RequestClientParser.getClientIdent(uuidString: clientParameter.client_id)
            guard let _client = Client.find(
                in: request.application.entityStorage, clientId: client_id.uuidString
            ) else {
                Log.error("CLIENT_NOT_FOUND: \(client_id)", requestId: request.id)
                throw RequestClientParserErrors.CLIENT_NOT_FOUND(client_id)
            }
            client = _client
            return
        } else {
            // then from query
            if let clientResult: ClientIdParameter = try? request.query.decode(ClientIdParameter.self) {
                let client_id = try RequestClientParser.getClientIdent(uuidString: clientResult.client_id)
                guard let _client = Client.find(
                in: request.application.entityStorage, clientId: client_id.uuidString
            ) else {
                    Log.error("CLIENT_NOT_FOUND: \(client_id)", requestId: request.id)
                    throw RequestClientParserErrors.CLIENT_NOT_FOUND(client_id)
                }
                client = _client
                return
            }
        }
        throw RequestClientParserErrors.NO_DATA
    }

    // MARK: - Private Helpers

    /// Validates and converts a UUID string to a UUID instance.
    ///
    /// - Parameter uuidString: The UUID string to validate
    /// - Returns: A valid UUID instance
    /// - Throws: ``RequestClientParserErrors/INVALID_UUID`` if the string is not a valid UUID
    private static func getClientIdent(uuidString: String) throws -> UUID {
        guard let ident = UUID(uuidString: uuidString) else {
            Log.error("Can't construct a UUID out of the clients id: '\(uuidString)'")
            throw RequestClientParserErrors.INVALID_UUID
        }
        return ident
    }
}
