import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("Tenant Provider Tests")
struct TenantProviderTest {

    @Test("Decodes a plain string entry as a raw script")
    func decodesStringAsScript() throws {
        let json = Data("\"class UserLoginProvider {}\"".utf8)
        let provider = try JSONDecoder().decode(TenantProvider.self, from: json)
        #expect(provider == .script("class UserLoginProvider {}"))
    }

    @Test("Decodes an object entry as a predefined provider")
    func decodesObjectAsPredefined() throws {
        let json = Data("""
        {"type":"uitrusting/v1","url":"uitrusting.acme.svc","token":"s3cret"}
        """.utf8)
        let provider = try JSONDecoder().decode(TenantProvider.self, from: json)
        guard case .predefined(let predefined) = provider else {
            Issue.record("expected a predefined provider")
            return
        }
        #expect(predefined.type == .uitrustingV1)
        #expect(predefined.url == "uitrusting.acme.svc")
        #expect(predefined.token == "s3cret")
    }

    @Test("Predefined provider token is optional")
    func predefinedTokenOptional() throws {
        let json = Data("""
        {"type":"uitrusting/v1","url":"uitrusting.acme.svc"}
        """.utf8)
        let provider = try JSONDecoder().decode(TenantProvider.self, from: json)
        guard case .predefined(let predefined) = provider else {
            Issue.record("expected a predefined provider")
            return
        }
        #expect(predefined.token == nil)
    }

    @Test("A mixed providers array round-trips through Codable")
    func mixedArrayRoundTrips() throws {
        let json = Data("""
        ["class UserLoginProvider {}",{"type":"uitrusting/v1","url":"u.svc"}]
        """.utf8)
        let providers = try JSONDecoder().decode([TenantProvider].self, from: json)
        #expect(providers.count == 2)
        #expect(providers[0] == .script("class UserLoginProvider {}"))

        // Encoding a script entry yields a plain string again (back-compat).
        let encoded = try JSONEncoder().encode(providers[0])
        #expect(String(data: encoded, encoding: .utf8) == "\"class UserLoginProvider {}\"")
    }

    @Test("providerScripts expands predefined providers to generated scripts")
    func providerScriptsExpandsPredefined() {
        let spec = TenantSpec(
            hosts: ["localhost"],
            providers: [
                .script("class UserValidationProvider {}"),
                .predefined(PredefinedProvider(type: .uitrustingV1, url: "uitrusting.acme.svc", token: nil))
            ]
        )
        let scripts = spec.providerScripts
        #expect(scripts.count == 2)
        #expect(scripts[0] == "class UserValidationProvider {}")
        // The predefined one is expanded to the generated Uitrusting login provider.
        #expect(scripts[1].contains("class UserLoginProvider"))
        #expect(scripts[1].contains("/verify"))
    }
}
