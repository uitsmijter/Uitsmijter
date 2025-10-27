import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("User Login Provider Tests")
struct UserLoginProviderTests {

    let providerScriptFetchExample = """
                                     class UserLoginProvider {
                                        isLoggedIn = false;
                                        constructor(credentials) {
                                           fetch("http://example.com", {
                                              method: "get"
                                           }).then((r) => {
                                             console.log(r.code, r.body.length);
                                             if(credentials.username == "ok@example.com"){
                                                  this.isLoggedIn = true;
                                             }
                                             commit(r);
                                           });
                                        }

                                        // Getter
                                        get canLogin() {
                                           return this.isLoggedIn;
                                        }

                                        get userProfile() {
                                           return {
                                              name: "Sander Foles",
                                              species: "Musician",
                                           };
                                        }
                                     }
                                     """

    let userOK = JSInputCredentials(username: "ok@example.com", password: "very-secret")
    let userDenied = JSInputCredentials(username: "deni@example.com", password: "very-secret")

    @Test("Get example with callback")
    func getExampleCallback() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try? await configure(app)

        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScriptFetchExample)

        let bodies = try await cbi.start(class: .userLogin, arguments: userOK)
        #expect(bodies.count == 1)
        guard let firstBody = bodies.first else {
            Issue.record("No body available")
            return
        }
        #expect(firstBody?.contains("Example Domain") == true)
    }

    @Test("Get example async")
    func getExampleAsync() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try? await configure(app)

        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScriptFetchExample)
        let bodies = try await cbi.start(class: .userLogin, arguments: userOK)
        #expect(bodies.count == 1)
        #expect(bodies.first!!.contains("Example Domain")) // swiftlint:disable:this force_unwrapping
    }

    @Test("Get example can login")
    func getExample_canLogin() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try? await configure(app)

        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScriptFetchExample)
        _ = try await cbi.start(class: .userLogin, arguments: userOK)

        let canLogin: Bool = try await cbi.getValue(class: .userLogin, property: "canLogin")
        #expect(canLogin)
    }

    @Test("Get example cannot login")
    func getExample_canNotLogin() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try? await configure(app)

        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScriptFetchExample)
        _ = try await cbi.start(class: .userLogin, arguments: userDenied)

        let canLogin: Bool = try await cbi.getValue(class: .userLogin, property: "canLogin")
        #expect(!canLogin)
    }

    @Test("Get example profile string")
    func getExample_ProfileString() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try? await configure(app)

        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScriptFetchExample)
        _ = try await cbi.start(class: .userLogin, arguments: userOK)

        struct ResultObject: Codable {
            let name: String
            let species: String
        }

        let profile: ResultObject = try await cbi.getObject(class: .userLogin, property: "userProfile")
        #expect(profile.name.contains("Sander Foles"))
        #expect(profile.species.contains("Musician"))
    }

    let providerScriptSyntaxError = """
                                    xclass UserLoginProvider {
                                       isLoggedIn = false;
                                    """

    @Test(
        "Get script that does not have user profile property throws error",
        .bug("https://github.com/example/issues/123", "Syntax error should be thrown")
    )
    func getScriptThatDoesNotHaveUserProfileProperty() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try? await configure(app)

        let cbi = JavaScriptProvider()
        await #expect(throws: (any Error).self) {
            try await cbi.loadProvider(script: providerScriptSyntaxError)
        }
    }
}
