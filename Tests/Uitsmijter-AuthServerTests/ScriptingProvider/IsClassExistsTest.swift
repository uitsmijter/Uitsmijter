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

@Suite("Class Does Not Exist Tests")
struct IsClassNotExistsTest {

    @Test("No classes defined returns false for UserLoginProvider")
    func noClassesDefinedUserLogin() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: "// No classes defined")
        let result = await jsp.isClassExists(class: .userLogin)
        #expect(!result)
    }

    @Test("No classes defined returns false for UserValidateProvider")
    func noClassesDefinedUserValidate() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: "// No classes defined")
        let result = await jsp.isClassExists(class: .userValidate)
        #expect(!result)
    }

    @Test("Wrong class name returns false")
    func wrongClassName() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
                                         class SomeOtherClass {
                                           constructor(){};
                                         }
                                         """)
        let result = await jsp.isClassExists(class: .userLogin)
        #expect(!result)
    }

    @Test("Empty script returns false")
    func emptyScript() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: "")
        let result = await jsp.isClassExists(class: .userLogin)
        #expect(!result)
    }
}
