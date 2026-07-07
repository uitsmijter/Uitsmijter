import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("Uitrusting Provider Script Tests")
struct UitrustingProviderScriptTest {

    @Test("Generated script targets the /verify endpoint and prepends a scheme")
    func targetsVerifyEndpoint() {
        let script = UitrustingProviderScript.make(url: "uitrusting.acme.svc", token: nil)
        #expect(script.contains("\"http://uitrusting.acme.svc/verify\""))
    }

    @Test("An explicit scheme in the url is preserved")
    func preservesExplicitScheme() {
        let script = UitrustingProviderScript.make(url: "https://uitrusting.acme.svc/", token: nil)
        #expect(script.contains("\"https://uitrusting.acme.svc/verify\""))
    }

    @Test("The internal token is sent as a header only when configured")
    func tokenHeaderOnlyWhenSet() {
        let withToken = UitrustingProviderScript.make(url: "u.svc", token: "s3cret")
        #expect(withToken.contains("X-Internal-Token"))
        #expect(withToken.contains("s3cret"))

        let withoutToken = UitrustingProviderScript.make(url: "u.svc", token: nil)
        #expect(!withoutToken.contains("X-Internal-Token"))
    }

    @Test("Login sends a SHA256 password_hash, never the plain password")
    func loginSendsPasswordHash() {
        let script = UitrustingProviderScript.make(url: "u.svc", token: nil)
        #expect(script.contains("password_hash: sha256(credentials.password)"))
        #expect(!script.contains("password: credentials.password"))
    }

    @Test("Validation posts username + tenant without a password hash")
    func validationOmitsPasswordHash() {
        let script = UitrustingProviderScript.make(url: "u.svc", token: nil)
        #expect(script.contains("class UserValidationProvider"))
        // The validation body carries username + tenant but no password_hash.
        let validationPart = script.components(separatedBy: "class UserValidationProvider").last ?? ""
        #expect(!validationPart.contains("password_hash"))
    }

    @Test("Generated script is valid JS and defines both provider classes")
    func generatedScriptLoadsAsValidJS() async throws {
        let provider = JavaScriptProvider()
        let script = UitrustingProviderScript.make(url: "uitrusting.acme.svc", token: "tok")
        // loadProvider throws on a syntax error; a clean load proves the generated JS parses.
        try await provider.loadProvider(script: script)
        #expect(await provider.isClassExists(class: .userLogin))
        #expect(await provider.isClassExists(class: .userValidate))
    }
}
