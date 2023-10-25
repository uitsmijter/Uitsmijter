@testable import Server
import Foundation
import XCTVapor

final class TenantEncoderTest: XCTestCase {

    func testConstructTenantFromYaml() async throws {
        let input = """
                    ---
                    name: MyTenant
                    config:
                      hosts:
                        - localhost
                        - example.com
                      interceptor:
                        enabled: false
                      providers:
                        - class UserLoginProvider {
                          constructor(credentials) { commit(true); }
                          get canLogin() { return true; }
                          get userProfile() { return {name:"Local Admin"}; }
                          get role() { return "normal"; }
                          }
                      silent_login: false
                    """
        let tenant = try Tenant(yaml: input)
        XCTAssertEqual(tenant.name, "MyTenant")
    }

    func testConstructTenantFromJson() async throws {
        // swiftlint:disable line_length
        let data = """
                   {
                     "name": "MyTenant",
                     "config": {
                       "hosts": [
                         "localhost",
                         "example.com"
                       ],
                       "interceptor": {
                         "enabled": false
                       },
                       "providers": [
                         "class UserLoginProvider {constructor(credentials) { commit(true); } get canLogin() { return true; } get userProfile() { return {name:'Local Admin'}; } get role() { return 'normal'; }}"
                       ],
                       "silent_login": false
                     }
                   }
                   """.data(using: .utf8)
        // swiftlint:enable line_length

        guard let data else {
            throw TestError.fail(withError: "no data available")
        }

        let tenant = try JSONDecoder().decode(Tenant.self, from: data)
        XCTAssertEqual(tenant.name, "MyTenant")
    }
}
