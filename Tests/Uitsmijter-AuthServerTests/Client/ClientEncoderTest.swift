import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@MainActor
@Suite struct ClientEncoderTest {

    @Test func constructClientFromYaml() async throws {
        let input = """
                    ---
                    name: MyClient
                    config:
                      ident: 995A4D66-6E80-41E6-8F4F-7C614836158D
                      tenantname: MyTenant
                      redirect_urls:
                        - https://localhost/.*
                        - https://example.com/.*
                      scopes:
                        - list
                      referrers:
                        - https://localhost/login
                        - https://example.com/login
                      isPkceOnly: false
                    """
        let client = try Client(yaml: input)
        #expect(client.name == "MyClient")
    }

    @Test func constructClientFromJson() async throws {
        let data = Data("""
                   {
                     "name": "MyClient",
                     "config":{
                       "ident": "995A4D66-6E80-41E6-8F4F-7C614836158D",
                       "tenantname": "MyTenant",
                       "redirect_urls": [
                         "https://localhost/.*",
                         "https://example.com/.*"
                       ],
                       "scopes": [
                         "list"
                       ],
                       "referrers": [
                         "https://localhost/login",
                         "https://example.com/login"
                       ],
                       "isPkceOnly": false
                     }
                   }
                   """.utf8)

        let client = try JSONDecoder().decode(Client.self, from: data)
        #expect(client.name == "MyClient")
    }
}
