import Foundation
import Vapor

final class VersionsController: RouteCollection {

    /// Load handled /versions routes
    func boot(routes: RoutesBuilder) throws {
        let versions = routes.grouped("versions")
        if Constants.SECURITY.DISPLAY_VERSION {
            versions.get(use: getVersions)
        }
    }

    /// return a simple version string
    func getVersions(_ req: Request) throws -> String {
        PackageBuild.info.describe
    }

}
