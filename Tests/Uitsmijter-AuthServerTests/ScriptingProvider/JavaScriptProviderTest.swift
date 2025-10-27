import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("JavaScript Provider Core Tests")
struct JavaScriptProviderTest {

    let dummyCredentials = JSInputCredentials(username: "test@example.com", password: "test")

    @Test("JavaScriptProvider initializes successfully")
    func providerInitializes() async throws {
        let jsp = JavaScriptProvider()
        // Just verify it creates without crashing
        let results = await jsp.committedResults
        #expect(results == nil)
    }

    @Test("loadProvider throws syntaxError for invalid syntax")
    func loadProviderThrowsSyntaxError() async throws {
        let jsp = JavaScriptProvider()
        await #expect(throws: JavaScriptProvider.JavaScriptError.self) {
            try await jsp.loadProvider(script: "class UserLoginProvider { invalid syntax")
        }
    }

    @Test("getValue returns Double for numeric property")
    func getValueReturnsDouble() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit(null);
                }
                get numericValue() {
                    return 42.5;
                }
            }
        """)

        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let value: Double = try await jsp.getValue(class: .userLogin, property: "numericValue")

        #expect(value == 42.5)
    }

    @Test("getValue returns String for string property")
    func getValueReturnsString() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit(null);
                }
                get stringValue() {
                    return "hello world";
                }
            }
        """)

        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let value: String = try await jsp.getValue(class: .userLogin, property: "stringValue")

        #expect(value == "hello world")
    }

    @Test("getValue returns Bool for boolean property")
    func getValueReturnsBool() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit(null);
                }
                get boolValue() {
                    return true;
                }
            }
        """)

        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let value: Bool = try await jsp.getValue(class: .userLogin, property: "boolValue")

        #expect(value == true)
    }

    @Test("start with callback-based completion works")
    func startWithCallbackCompletion() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit({subject: "callback_test"});
                }
                get canLogin() {
                    return true;
                }
            }
        """)

        // Test that callback version works by using the async wrapper which internally uses callback
        let results = try await jsp.start(class: .userLogin, arguments: dummyCredentials)

        #expect(!results.isEmpty)
    }

    @Test("isClassExists returns true for defined class")
    func isClassExistsReturnsTrue() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {}
            }
        """)

        let exists = await jsp.isClassExists(class: .userLogin)
        #expect(exists == true)
    }

    @Test("isClassExists returns false for undefined class")
    func isClassExistsReturnsFalse() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class SomeOtherClass {
                constructor() {}
            }
        """)

        let exists = await jsp.isClassExists(class: .userLogin)
        #expect(exists == false)
    }

    @Test("custom script class execution with userValidate")
    func customScriptClassWithUserValidate() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserValidationProvider {
                constructor(args) {
                    commit(null);
                }
                get isValid() {
                    return true;
                }
            }
        """)

        _ = try await jsp.start(class: .userValidate, arguments: dummyCredentials)
        let isValid: Bool = try await jsp.getValue(class: .userValidate, property: "isValid")

        #expect(isValid == true)
    }

    @Test("committedResults stores values after commit")
    func committedResultsStoresValues() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit({subject: "test_subject", data: "test_data"});
                }
            }
        """)

        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let results = await jsp.committedResults

        #expect(results != nil)
        #expect(results?.isEmpty == false)
    }

    @Test("getObject returns complex object")
    func getObjectReturnsComplexObject() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit(null);
                }
                get complexObject() {
                    return {
                        name: "Test User",
                        age: 25,
                        active: true
                    };
                }
            }
        """)

        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let obj: CodableProfile? = try? await jsp.getObject(class: .userLogin, property: "complexObject")

        #expect(obj != nil)
    }
}
