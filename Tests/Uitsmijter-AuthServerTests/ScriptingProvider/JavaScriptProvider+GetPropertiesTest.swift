import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer
@Suite("JavaScript Provider Get Properties Tests")
struct JavaScriptProviderGetPropertiesTest {
    let dummyCredentials = JSInputCredentials(username: "test@example.com", password: "test")
    @Test("getSubject returns committed subject from script")
    func getSubjectReturnsCommittedSubject() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit({subject: "user12345"});
                }
                get canLogin() {
                    return true;
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let subject = await jsp.getSubject(loginHandle: "fallback@example.com")
        #expect(subject.subject.value == "user12345")
    }
    @Test("getSubject returns default when no subject committed")
    func getSubjectReturnsDefaultWhenNoCommit() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit(null);
                }
                get canLogin() {
                    return true;
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let subject = await jsp.getSubject(loginHandle: "default@example.com")
        #expect(subject.subject.value == "default@example.com")
    }
    @Test("getSubject uses loginHandle as fallback")
    func getSubjectUsesLoginHandleAsFallback() async throws {
        let jsp = JavaScriptProvider()
        let subject = await jsp.getSubject(loginHandle: "myuser@test.com")
        #expect(subject.subject.value == "myuser@test.com")
    }
    @Test("getProfile returns user profile from script")
    func getProfileReturnsUserProfile() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) { commit(null); }
                get canLogin() {
                    return true;
                }
                get userProfile() {
                    return {
                        name: "John Doe",
                        email: "john@example.com",
                        age: 30
                    };
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let profile = await jsp.getProfile(scriptClass: .userLogin)
        #expect(profile != nil)
    }
    @Test("getProfile returns nil when no profile defined")
    func getProfileReturnsNilWhenNoProfile() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) { commit(null); }
                get canLogin() {
                    return true;
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let profile = await jsp.getProfile(scriptClass: .userLogin)
        #expect(profile == nil)
    }
    @Test("getProfile returns nil before script execution")
    func getProfileReturnsNilBeforeExecution() async throws {
        let jsp = JavaScriptProvider()
        let profile = await jsp.getProfile(scriptClass: .userLogin)
        #expect(profile == nil)
    }
    @Test("getRole returns role from script")
    func getRoleReturnsRoleFromScript() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) { commit(null); }
                get canLogin() {
                    return true;
                }
                get role() {
                    return "admin";
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let role = await jsp.getRole(scriptClass: .userLogin)
        #expect(role == "admin")
    }
    @Test("getRole returns default when no role defined")
    func getRoleReturnsDefaultWhenNoRole() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) { commit(null); }
                get canLogin() {
                    return true;
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let role = await jsp.getRole(scriptClass: .userLogin)
        #expect(role == "default")
    }
    @Test("getRole returns default before script execution")
    func getRoleReturnsDefaultBeforeExecution() async throws {
        let jsp = JavaScriptProvider()
        let role = await jsp.getRole(scriptClass: .userLogin)
        #expect(role == "default")
    }
    @Test("getRole handles different role values")
    func getRoleHandlesDifferentValues() async throws {
        let roles = ["user", "moderator", "superadmin", "guest", "custom_role"]
        for testRole in roles {
            let jsp = JavaScriptProvider()
            _ = try await jsp.loadProvider(script: """
                class UserLoginProvider {
                    constructor(credentials) { commit(null); }
                    get canLogin() {
                        return true;
                    }
                    get role() {
                        return "\(testRole)";
                    }
                }
            """)
            _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
            let role = await jsp.getRole(scriptClass: .userLogin)
            #expect(role == testRole)
        }
    }
    @Test("canLogin is already tested but verify it works")
    func canLoginVerification() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) { commit(null); }
                get canLogin() {
                    return true;
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let canLogin = await jsp.canLogin(scriptClass: .userLogin)
        #expect(canLogin == true)
    }
    @Test("all get properties work together")
    func allGetPropertiesWorkTogether() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    commit({subject: "integration_test_user"});
                }
                get canLogin() {
                    return true;
                }
                get userProfile() {
                    return {
                        firstName: "Jane",
                        lastName: "Smith",
                        department: "Engineering"
                    };
                }
                get role() {
                    return "developer";
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let subject = await jsp.getSubject(loginHandle: "fallback")
        let profile = await jsp.getProfile(scriptClass: .userLogin)
        let role = await jsp.getRole(scriptClass: .userLogin)
        let canLogin = await jsp.canLogin(scriptClass: .userLogin)
        #expect(subject.subject.value == "integration_test_user")
        #expect(profile != nil)
        #expect(role == "developer")
        #expect(canLogin == true)
    }
    @Test("getProfile with empty object")
    func getProfileWithEmptyObject() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) { commit(null); }
                get canLogin() {
                    return true;
                }
                get userProfile() {
                    return {};
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let profile = await jsp.getProfile(scriptClass: .userLogin)
        #expect(profile != nil)
    }
    @Test("getRole with empty string role")
    func getRoleWithEmptyString() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) { commit(null); }
                get canLogin() {
                    return true;
                }
                get role() {
                    return "";
                }
            }
        """)
        _ = try await jsp.start(class: .userLogin, arguments: dummyCredentials)
        let role = await jsp.getRole(scriptClass: .userLogin)
        #expect(role == "")
    }
}
