import Foundation
import Vapor

//
//  Application+AuthCodeStorage.swift
//  Uitsmijter
//
//  Created by Kris Simon on 14.11.25.
//

/// A storage key for registering ``AuthCodeStorage`` in Vapor's application storage.
///
/// This key enables dependency injection of the authorization code storage throughout
/// the Vapor application via the storage container pattern.
///
/// ## See Also
///
/// - ``Application/authCodeStorage``
struct AuthCodeStorageKey: StorageKey {
    typealias Value = AuthCodeStorage
}

/// Vapor application extension providing access to authorization code storage.
extension Application {
    /// The authorization code storage instance for this application.
    ///
    /// This property provides centralized access to the configured storage backend
    /// throughout the Vapor application. It's typically set during application
    /// configuration based on environment settings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Configure in configure.swift
    /// if app.environment == .production {
    ///     app.authCodeStorage = AuthCodeStorage(use: .redis(redisClient))
    /// } else {
    ///     app.authCodeStorage = AuthCodeStorage(use: .memory)
    /// }
    ///
    /// // Access in route handlers
    /// func token(req: Request) async throws -> TokenResponse {
    ///     let storage = req.application.authCodeStorage
    ///     let session = await storage?.get(type: .code, codeValue: code)
    ///     // ...
    /// }
    /// ```
    var authCodeStorage: AuthCodeStorage? {
        get {
            storage[AuthCodeStorageKey.self]
        }
        set {
            storage[AuthCodeStorageKey.self] = newValue
        }
    }
}
