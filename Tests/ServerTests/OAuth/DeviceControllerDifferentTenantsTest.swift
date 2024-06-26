import Foundation
import XCTVapor
@testable import Server

final class DeviceControllerDifferentTenantsTest: XCTestCase {
    let testAppIdent1 = UUID()
    let testAppIdent2 = UUID()
    let app = Application(.testing)

    override func setUp() {
        super.setUp()

        generateTestClientsWithMultipleTenants(
            uuids: [testAppIdent1, testAppIdent2], 
            script: .johnDoe,
            scopes: nil, 
            referrers: nil,
            grant_types: [.authorization_code, .refresh_token, .device]
        )
        try? configure(app)
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCreatedExpectedSet() {
        XCTAssertGreaterThanOrEqual(EntityStorage.shared.tenants.count, 2)
        XCTAssertGreaterThanOrEqual(EntityStorage.shared.clients.count, 2)
    }

    func testCanLoginWithAllowedDevice() async throws {
        // select
        let tenant = EntityStorage.shared.tenants.first { element in
            element.config.hosts.contains("127.0.0.1")
        }
        let client = EntityStorage.shared.clients.first { element in
            element.config.tenant?.name == tenant?.name
        }
        XCTAssertNotNil(tenant)
        XCTAssertNotNil(client)

        guard let client else {
            XCTFail("Client is nil")
            return
        }
        
        let responseDeviceCode = try app.sendRequest(.POST, "/device", beforeRequest: ({ req in
            req.headers = ["Content-Type": "application/json"]
            try req.content.encode(
                DeviceRequest(client_id: client.config.ident.uuidString )
            )
        }))
        XCTAssertEqual(responseDeviceCode.status, .ok)
        dump(responseDeviceCode)
        
    }

}
