import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@MainActor
@Suite struct TenantEncoderTest {

    @Test func constructTenantFromYaml() async throws {
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
        #expect(tenant.name == "MyTenant")
    }

    @Test func constructTenantFromJson() async throws {
        let data = Data("""
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
                   """.utf8)

        let tenant = try JSONDecoder().decode(Tenant.self, from: data)
        #expect(tenant.name == "MyTenant")
    }
}
