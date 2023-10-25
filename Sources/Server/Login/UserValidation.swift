import Foundation
import Vapor

/// Validates the user against the Backend Providers
struct UserValidation {

    /// is the user still valid?
    /// The tenant is taken from the request.clientIndo
    ///
    /// - Parameters:
    ///   - username: The name which the user is logged in
    ///   - request: The current request
    /// - Returns: true if the user is still valid
    /// - Throws: an error if a prerequisite fails
    static func isStillValid(username: String, on request: Request) async throws -> Bool {
        guard let tenant = request.clientInfo?.tenant else {
            throw Abort(.forbidden, reason: "LOGIN.ERRORS.NO_TENANT")
        }
        return try await isStillValid(username: username, tenant: tenant, on: request)
    }

    /// is the user still valid?
    ///
    /// - Parameters:
    ///   - username: The name which the user is logged in
    ///   - tenant: The tenant object that is used to check
    ///   - request: The current request
    /// - Returns: true if the user is still valid
    /// - Throws: an error if a prerequisite fails
    static func isStillValid(username: String, tenant: Tenant, on request: Request) async throws -> Bool {
        let providerInterpreter = JavaScriptProvider()
        try providerInterpreter.loadProvider(script: tenant.config.providers.joined(separator: "\n"))

        if providerInterpreter.isClassExists(class: .userValidate) == false {
            if Constants.SECURITY.ALLOW_MISSING_PROVIDERS == false {
                Log.critical("""
                             ALLOW_MISSING_PROVIDERS is turned off. Refresh process is
                             aborted, because userValidate is not defined in \(tenant.name)
                             """, request: request
                )
                throw Abort(.serviceUnavailable, reason: "ERRORS.EXPECTED_VALUE_UNSET")
            }
            Log.error("""
                      Tenant \(tenant.name)'s userValidate provider is not present
                      Users are logged in forever! Please turn ALLOW_MISSING_PROVIDERS
                      off.
                      """, request: request)
            return true
        }

        // Class exists, so lets validate
        try await providerInterpreter.start(
                class: .userValidate,
                arguments: JSInputUsername(
                        username: username
                )
        )

        // Ask the provider if the user is still valid
        if try providerInterpreter.getValue(class: .userValidate, property: "isValid") == true {
            return true
        }
        Log.info(
                "Can not refresh token for user \(username), because of invalidation",
                request: request
        )
        return false
    }
}
