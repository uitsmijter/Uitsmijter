import Foundation

/// Errors that can occur when parsing client information from requests
enum RequestClientParserErrors: Error {
    case INVALID_UUID
    case NO_DATA
    case CLIENT_NOT_FOUND(UUID)
}
