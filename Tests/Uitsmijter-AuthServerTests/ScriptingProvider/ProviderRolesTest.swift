import Foundation
import Testing
import JWTKit
@testable import Uitsmijter_AuthServer

@Suite("Provider Roles Tests")
struct ProviderRolesTest {

    private func credentials() -> JSInputCredentials {
        JSInputCredentials(
            username: "user@example.com",
            password: "secret",
            grantType: .authorization_code,
            tenant: JSInputTenant(name: "acme")
        )
    }

    @Test("getRoles returns the roles array a provider exposes")
    func getRolesReturnsArray() async throws {
        let script = """
        class UserLoginProvider {
            constructor(credentials) { commit(true); }
            get canLogin() { return true; }
            get roles() { return ["admin", "editor"]; }
        }
        """
        let provider = JavaScriptProvider()
        try await provider.loadProvider(script: script)
        try await provider.start(class: .userLogin, arguments: credentials())

        let roles = await provider.getRoles()
        #expect(roles == ["admin", "editor"])
    }

    @Test("getRoles returns nil when the provider exposes no roles")
    func getRolesNilWhenAbsent() async throws {
        let script = """
        class UserLoginProvider {
            constructor(credentials) { commit(true); }
            get canLogin() { return true; }
            get role() { return "user"; }
        }
        """
        let provider = JavaScriptProvider()
        try await provider.loadProvider(script: script)
        try await provider.start(class: .userLogin, arguments: credentials())

        let roles = await provider.getRoles()
        #expect(roles == nil)
    }

    @Test("Payload encodes the roles claim and omits it when nil")
    func payloadRolesClaimRoundTrips() throws {
        let base = Payload(
            issuer: IssuerClaim(value: "https://localhost"),
            subject: "sub",
            audience: AudienceClaim(value: "client"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            authTime: AuthTimeClaim(value: Date()),
            tenant: "acme",
            role: "admin",
            roles: ["admin", "editor"],
            user: "user@example.com"
        )
        let json = try JSONEncoder().encode(base)
        let decoded = try JSONDecoder().decode(Payload.self, from: json)
        #expect(decoded.roles == ["admin", "editor"])
        #expect(String(data: json, encoding: .utf8)?.contains("\"roles\"") == true)

        // No roles → claim omitted.
        var single = base
        single.roles = nil
        let singleJson = try JSONEncoder().encode(single)
        #expect(String(data: singleJson, encoding: .utf8)?.contains("\"roles\"") == false)
    }
}
