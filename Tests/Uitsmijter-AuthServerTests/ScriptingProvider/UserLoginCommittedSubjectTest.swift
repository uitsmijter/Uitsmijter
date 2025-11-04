import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("User Login Committed Subject Tests")
struct UserLoginCommittedSubjectTest {

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

    @Test("Get committed value can login")
    func getCommittedValue_canLogin() async throws {
        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScriptFetchExample)
        let directValue = try await cbi.start(class: .userLogin, arguments: userOK)
        let fetchedValue = await cbi.committedResults

        #expect(directValue == fetchedValue)

        // is subject given in fetchedValue
        let subjects = Subject.decode(from: fetchedValue?.compactMap({ $0 }))

        #expect(subjects.count == 1)
        #expect(subjects.first!.subject == "189367") // swiftlint:disable:this force_unwrapping
    }

    @Test("Get committed value cannot login")
    func getCommittedValue_canNotLogin() async throws {
        let cbi = JavaScriptProvider()
        try await cbi.loadProvider(script: providerScriptFetchExample)
        let directValue = try await cbi.start(class: .userLogin, arguments: userDenied)
        let fetchedValue = await cbi.committedResults

        #expect(directValue == fetchedValue)

        // is subject given in fetchedValue
        let subjects = Subject.decode(from: fetchedValue?.compactMap({ $0 }))

        #expect(subjects.isEmpty)
    }
}
