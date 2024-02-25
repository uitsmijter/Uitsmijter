import Foundation

@testable import Server
import XCTVapor

final class UserLoginProviderTests: XCTestCase {

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

    func testGetExampleCallback() async throws {
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScriptFetchExample)
        let expect = expectation(description: "userValidate response")
        cbi.start(class: .userLogin, arguments: userOK) { result in
            do {
                let bodies = try result.get()
                XCTAssertEqual(bodies.count, 1)
                guard let firstBody = bodies.first else {
                    XCTFail("No body available")
                    return
                }
                XCTAssertContains(firstBody, "Example Domain")
                expect.fulfill()
            } catch {
                if let err = error as? JavaScriptProvider.JavaScriptError {
                    switch err {
                    case .timeout:
                        XCTAssert(false, "Call timed out)")
                    default:
                        XCTAssert(false, "other error. \(error.localizedDescription)")
                    }
                }
            }
        }
        wait(for: [expect], timeout: TestDefaults.waitTimeout)
    }

    func testGetExampleAsync() async throws {
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScriptFetchExample)
        let bodies = try await cbi.start(class: .userLogin, arguments: userOK)
        XCTAssertEqual(bodies.count, 1)
        XCTAssertContains(bodies.first!!, "Example Domain") // swiftlint:disable:this force_unwrapping
    }

    func testGetExample_canLogin() async throws {
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScriptFetchExample)
        _ = try await cbi.start(class: .userLogin, arguments: userOK)

        let canLogin: Bool = try cbi.getValue(class: .userLogin, property: "canLogin")
        XCTAssertTrue(canLogin)
    }

    func testGetExample_canNotLogin() async throws {
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScriptFetchExample)
        _ = try await cbi.start(class: .userLogin, arguments: userDenied)

        let canLogin: Bool = try cbi.getValue(class: .userLogin, property: "canLogin")
        XCTAssertFalse(canLogin)
    }

    func testGetExample_ProfileString() async throws {
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScriptFetchExample)
        _ = try await cbi.start(class: .userLogin, arguments: userOK)

        struct ResultObject: Codable {
            let name: String
            let species: String
        }

        let profile: ResultObject = try cbi.getObject(class: .userLogin, property: "userProfile")
        XCTAssertContains(profile.name, "Sander Foles")
        XCTAssertContains(profile.species, "Musician")
    }

    let providerScriptSyntaxError = """
                                    xclass UserLoginProvider {
                                       isLoggedIn = false;
                                    """

    func testGetScriptThatDoesNotHaveUserProfileProperty() async throws {
        let cbi = JavaScriptProvider()
        try XCTAssertThrowsError(cbi.loadProvider(script: providerScriptSyntaxError))
    }
}
