import Foundation
import JWT

/// Extends `JavaScriptProvider` to get the values for common properties
extension JavaScriptProvider {

    /// Get the committed subject or the given default
    ///
    /// - Parameter loginHandle: Pass the login handle (username. login name, ect.)
    /// - Returns: An object based on `SubjectProtocol` with a `SubjectClaim`
    func getSubject(loginHandle: String) -> SubjectProtocol {
        Subject.decode(
                from: committedResults?.compactMap({ $0 })
        ).first ?? Subject(subject: JWT.SubjectClaim(value: loginHandle))
    }

    /// Returns true if the user is allowed to login
    ///
    /// - Parameter:
    /// - Returns: A boolean indication of the rights to login
    func canLogin(scriptClass: ScriptClassExecution = .userLogin) -> Bool {
        if let canLogin: Bool = try? self.getValue(class: .userLogin, property: "canLogin") {
            return canLogin
        }
        return false
    }

    /// Returns the profile form `scriptClass`.
    ///
    /// - Parameter scriptClass: a `ScriptClassExecution`, default: userBackend
    /// - Returns: The users `profile` as a `CodableProfile`
    func getProfile(scriptClass: ScriptClassExecution = .userLogin) -> CodableProfile? {
        let profile: CodableProfile? = try? self.getObject(class: scriptClass, property: "userProfile")
        return profile
    }

    /// Returns the role property form `scriptClass`.
    ///
    /// - Parameter scriptClass: a `ScriptClassExecution`, default: userBackend
    /// - Returns: The `role` as a `String`
    func getRole(scriptClass: ScriptClassExecution = .userLogin) -> String {
        let role: String? = try? self.getObject(class: scriptClass, property: "role")
        guard let role else {
            return "default"
        }
        return role
    }

}
