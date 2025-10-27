import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("Is Class Exists Tests")
struct IsClassExistsTest {

    @Test("Class exists returns true")
    func classExists() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
                                         class UserLoginProvider {
                                           constructor(){};
                                         }
                                         """)
        let result = await jsp.isClassExists(class: .userLogin)
        #expect(result)
    }

    @Test("Class does not exist returns false")
    func classDoNotExists() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
                                         class UserLoginProvider {
                                           constructor(){};
                                         }
                                         """)
        let result = await jsp.isClassExists(class: .userValidate)
        #expect(!result)
    }
}
