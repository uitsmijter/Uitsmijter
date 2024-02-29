import Foundation

@testable import Server
import XCTVapor

final class UserLoginCommittedSubjectTest: XCTestCase {

    /// Provider that returns a subject if login = ok@example.com
    let providerScriptFetchExample = """
                                     class UserLoginProvider {
                                        isLoggedIn = false;
                                        profile = null;
                                        constructor(credentials) {
                                             if(credentials.username == "ok@example.com"){
                                                  this.isLoggedIn = false;
                                                  this.profile = { "name": "Clark Terry" };
                                                  return commit({"subject": "189367"});
                                             }
                                             commit(null);
                                        }

                                        // Getter
                                        get canLogin() {
                                           return this.isLoggedIn;
                                        }

                                        get userProfile() {
                                           return this.profile;
                                        }
                                     }
                                     """

    let userOK = JSInputCredentials(username: "ok@example.com", password: "very-secret")
    let userDenied = JSInputCredentials(username: "deni@example.com", password: "very-secret")

    func testGetCommittedValue_canLogin() async throws {
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScriptFetchExample)
        let directValue = try await cbi.start(class: .userLogin, arguments: userOK)
        let fetchedValue = cbi.committedResults

        XCTAssertEqual(directValue, fetchedValue)

        // is subject given in fetchedValue
        let subjects = Subject.decode(from: fetchedValue?.compactMap({ $0 }))

        XCTAssertNotNil(subjects)
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects.first!.subject, "189367") // swiftlint:disable:this force_unwrapping
    }

    func testGetCommittedValue_canNotLogin() async throws {
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScriptFetchExample)
        let directValue = try await cbi.start(class: .userLogin, arguments: userDenied)
        let fetchedValue = cbi.committedResults

        XCTAssertEqual(directValue, fetchedValue)

        // is subject given in fetchedValue
        let subjects = Subject.decode(from: fetchedValue?.compactMap({ $0 }))

        XCTAssertNotNil(subjects)
        XCTAssertEqual(subjects.count, 0)
    }
}
