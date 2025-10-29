import Foundation

/// Errors that can occur during auth code storage operations
enum AuthCodeStorageError: Error {
    case CODE_TAKEN
    case KEY_ERROR
}
