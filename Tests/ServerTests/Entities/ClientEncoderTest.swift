@testable import Server
import Foundation
import XCTVapor

final class ClientEncoderTest: XCTestCase {

    func testConstructClientFromYaml() async throws {
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
        XCTAssertEqual(client.name, "MyClient")
    }

    func testConstructClientFromJson() async throws {
        let data = """
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
                   """.data(using: .utf8)

        guard let data else {
            throw TestError.fail(withError: "no data available")
        }

        let client = try JSONDecoder().decode(Client.self, from: data)
        XCTAssertEqual(client.name, "MyClient")
    }
}
