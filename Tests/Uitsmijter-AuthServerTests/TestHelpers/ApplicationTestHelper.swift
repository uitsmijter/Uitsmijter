import Foundation
import Vapor
import VaporTesting
@testable import Uitsmijter_AuthServer

/// Helper function to create and manage Application lifecycle for tests that need @MainActor isolation
/// This avoids the ServeCommand crash by ensuring proper shutdown sequence
@MainActor
func withTestApp<T>(_ test: (Application) async throws -> T) async throws -> T {
    let app = try await Application.make(.testing)
    do {
        let result = try await test(app)
        try await app.asyncShutdown()
        return result
    } catch {
        try await app.asyncShutdown()
        throw error
    }
}

/// Helper that also runs configure for convenience
@MainActor
func withConfiguredTestApp<T>(_ test: (Application) async throws -> T) async throws -> T {
    try await withTestApp { app in
        try configure(app)
        return try await test(app)
    }
}
