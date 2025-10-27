import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("User Validation Provider Tests")
struct UserValidationProviderTests {

    let providerScript = """
                         class UserValidationProvider {
                            isValid = false;
                            constructor(args) {
                                 if(args.username == "ok@example.com"){
                                      this.isValid = true;
                                 }
                                 commit(true);
                            }

                            // Getter
                            get isValid() {
                               return this.isValid;
                            }
                         }
                         """

    let userOK = JSInputUsername(username: "ok@example.com")
    let userDenied = JSInputUsername(username: "deni@example.com")

    @Test("Get example with callback")
    func getExampleCallback() async throws {
        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScript)

        let bodies = try await cbi.start(class: .userValidate, arguments: userOK)
        #expect(bodies.count == 1)
        guard let firstBody = bodies.first else {
            Issue.record("No body available")
            return
        }
        #expect(firstBody?.contains("true") == true)
    }

    @Test("User is valid")
    func isValid() async throws {
        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScript)
        _ = try await cbi.start(class: .userValidate, arguments: userOK)

        let isValid: Bool = try await cbi.getValue(class: .userValidate, property: "isValid")
        #expect(isValid)
    }

    @Test("User is invalid")
    func isInvalid() async throws {
        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScript)
        _ = try await cbi.start(class: .userValidate, arguments: userDenied)
        let isValid: Bool = try await cbi.getValue(class: .userValidate, property: "isValid")
        #expect(!isValid)
    }
}
