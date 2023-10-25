import Foundation
import Vapor

// https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata

struct WellKnownController: RouteCollection {

    /// Load handled routes
    func boot(routes: RoutesBuilder) throws {
        // let wellKnown = routes.grouped(".well-known")

        // wellKnown.get("openid-configuration", use: getConfiguration)
    }

//    /// Return a configuration for the oicd client

//    func getConfiguration(req: Request) -> OpenidConfiguration {
//        let openidConfiguration = OpenidConfiguration(
//                request_parameter_supported: true,
//                claims_parameter_supported: false,
//                scopes_supported: ["read", "profile"]
//        )
//        return openidConfiguration
//    }
}
