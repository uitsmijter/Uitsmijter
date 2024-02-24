// import Foundation

// import XCTVapor
// @testable import Server
 
// final class InterceptorControllerDifferentTenantsTest: XCTestCase {
//     let testAppIdent1 = UUID()
//     let testAppIdent2 = UUID()
//     let app = Application(.testing)
//     var tenant1: Tenant?
//     var tenant2: Tenant?

//     override func setUp() {
//         super.setUp()
//         generateTestClientsWithMultipleTenants(uuids: [testAppIdent1, testAppIdent2])
//         // swiftlint:disable force_unwrapping
//         tenant1 = EntityStorage.shared.clients.first(where: { $0.config.ident == testAppIdent1 })!.config.tenant
//         tenant2 = EntityStorage.shared.clients.first(where: { $0.config.ident == testAppIdent2 })!.config.tenant
//         // swiftlint:enable force_unwrapping
//         try? configure(app)
//     }

//     override func tearDown() {
//         app.shutdown()
//     }

//     func testInterceptorWithOtherTenantShouldFail() async throws {
//         guard let tenant1, let tenant2 else {
//             return XCTFail("No tenant")
//         }
//         let response = try app.sendRequest(.GET, "interceptor", beforeRequest: { req in
//             req.headers.bearerAuthorization = try validAuthorisation(for: tenant1, in: app)
//             req.headers.replaceOrAdd(name: "X-Forwarded-Proto", value: "http")
//             req.headers.replaceOrAdd(name: "X-Forwarded-Host", value: tenant2.config.hosts.first ?? "_ERROR_")
//             req.headers.replaceOrAdd(name: "X-Forwarded-Uri", value: "/test")
//         })

//         XCTAssertEqual(response.status, .forbidden)
//     }

// }
