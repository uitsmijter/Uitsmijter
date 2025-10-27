import Foundation
import Vapor

/// Controller providing application version information.
///
/// The `VersionsController` exposes the application's build version through a simple
/// HTTP endpoint. This is useful for:
/// - Verifying deployed versions in production
/// - Debugging deployment issues
/// - Monitoring rollout status
/// - API documentation and client compatibility checks
///
/// ## Security Considerations
///
/// Version display is controlled by the `Constants.SECURITY.DISPLAY_VERSION` flag.
/// When disabled, the route is not registered, preventing version information disclosure
/// that could aid attackers in identifying known vulnerabilities.
///
/// ## Route Registration
///
/// If enabled, registers:
/// - `GET /versions` - Returns version string (e.g., "1.2.3-beta+abc123")
///
/// ## Version Format
///
/// The version string is generated from `PackageBuild.info.describe` which typically
/// includes:
/// - Semantic version (e.g., "1.2.3")
/// - Pre-release identifiers (e.g., "-beta", "-rc1")
/// - Build metadata (e.g., git commit hash)
///
/// ## Example
///
/// ```swift
/// // Register routes in configure.swift
/// try app.register(collection: VersionsController())
///
/// // HTTP request
/// GET /versions
///
/// // Response
/// 1.2.3-beta+abc1234
/// ```
///
/// - Note: This controller is `Sendable` and safe for concurrent access.
/// - SeeAlso: ``Constants/SECURITY/DISPLAY_VERSION`` for configuration
/// - SeeAlso: ``PackageBuild`` for build information generation
final class VersionsController: RouteCollection, Sendable {

    /// Registers version routes with the application.
    ///
    /// This method conditionally registers the `/versions` endpoint based on the
    /// `Constants.SECURITY.DISPLAY_VERSION` security flag. When disabled, no routes
    /// are registered, completely hiding version information from the API surface.
    ///
    /// - Parameter routes: The routes builder to register endpoints with.
    /// - Throws: Routing configuration errors (typically none for this controller).
    func boot(routes: RoutesBuilder) throws {
        let versions = routes.grouped("versions")
        if Constants.SECURITY.DISPLAY_VERSION {
            versions.get(use: { @Sendable (req: Request) throws -> String in
                try self.getVersions(req)
            })
        }
    }

    /// Returns the application version as a string.
    ///
    /// This method retrieves the build version information from `PackageBuild.info.describe`,
    /// which provides a descriptive version string typically generated during the build process.
    ///
    /// ## Version String Format
    ///
    /// The returned string usually follows semantic versioning with optional metadata:
    /// - `1.2.3` - Standard release version
    /// - `1.2.3-beta` - Pre-release version
    /// - `1.2.3-beta+abc1234` - Pre-release with build metadata (git hash)
    /// - `1.2.3+abc1234` - Release with build metadata
    ///
    /// ## Usage
    ///
    /// ```bash
    /// curl http://localhost:8080/versions
    /// 1.2.3-beta+abc1234
    /// ```
    ///
    /// - Parameter req: The incoming HTTP request (unused but required by route signature).
    /// - Returns: The application version string.
    /// - Throws: Typically does not throw, but signature allows for routing errors.
    @Sendable func getVersions(_ req: Request) throws -> String {
        PackageBuild.info.describe
    }

}
