import Foundation
import Vapor
import Logger

// MARK: - User Validation

/// Validates user accounts against backend provider scripts.
///
/// This utility checks if a user account is still valid by executing the tenant's
/// `UserValidate` JavaScript provider. This is used during token refresh to ensure
/// users haven't been disabled or deleted in the backend system.
///
/// ## Provider Integration
///
/// The validation process:
/// 1. Loads the tenant's provider JavaScript
/// 2. Checks for the `UserValidate` class
/// 3. Executes the validation with the username
/// 4. Returns the `isValid` property from the provider
///
/// ## Security Behavior
///
/// - If `ALLOW_MISSING_PROVIDERS` is disabled and no provider exists, validation fails
/// - If `ALLOW_MISSING_PROVIDERS` is enabled and no provider exists, validation passes (insecure)
///
/// ## Example Provider
///
/// ```javascript
/// class UserValidate {
///     constructor(username) {
///         this.username = username;
///         this.isValid = checkUserInDatabase(username);
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Validation Methods
/// - ``isStillValid(username:on:)``
/// - ``isStillValid(username:tenant:on:)``
///
/// - SeeAlso: ``JavaScriptProvider``
/// - SeeAlso: ``Tenant``
/// - SeeAlso: ``Constants/SECURITY/ALLOW_MISSING_PROVIDERS``
struct UserValidation {

    /// Validates if a user is still active using the tenant from the request.
    ///
    /// This method extracts the tenant from `request.clientInfo` and delegates
    /// to the tenant-specific validation method.
    ///
    /// - Parameters:
    ///   - username: The username to validate
    ///   - request: The current request containing client and tenant info
    /// - Returns: `true` if the user is still valid, `false` otherwise
    /// - Throws:
    ///   - `Abort(.forbidden)` if no tenant is associated with the request
    ///   - `Abort(.serviceUnavailable)` if provider is missing and not allowed
    ///
    /// - SeeAlso: ``isStillValid(username:tenant:on:)``
    static func isStillValid(username: String, on request: Request) async throws -> Bool {
        guard let tenant = request.clientInfo?.tenant else {
            throw Abort(.forbidden, reason: "LOGIN.ERRORS.NO_TENANT")
        }
        return try await isStillValid(username: username, tenant: tenant, on: request)
    }

    /// Validates if a user is still active for a specific tenant.
    ///
    /// This method executes the tenant's `UserValidate` JavaScript provider to check
    /// if the user account is still active. This is critical for token refresh operations.
    ///
    /// ## Provider Execution
    ///
    /// 1. Loads all provider scripts for the tenant
    /// 2. Checks if `UserValidate` class exists
    /// 3. Instantiates the class with the username
    /// 4. Reads the `isValid` property
    ///
    /// ## Missing Provider Handling
    ///
    /// - **Development** (ALLOW_MISSING_PROVIDERS=true): Returns `true`, logs error
    /// - **Production** (ALLOW_MISSING_PROVIDERS=false): Throws error
    ///
    /// - Parameters:
    ///   - username: The username to validate
    ///   - tenant: The tenant whose provider scripts will be used
    ///   - request: The current request (for logging)
    /// - Returns: `true` if the user is still valid, `false` if invalidated by provider
    /// - Throws: `Abort(.serviceUnavailable)` if provider is missing and not allowed
    ///
    /// - SeeAlso: ``JavaScriptProvider``
    /// - SeeAlso: ``Constants/SECURITY/ALLOW_MISSING_PROVIDERS``
    static func isStillValid(username: String, tenant: Tenant, on request: Request) async throws -> Bool {
        let providerInterpreter = JavaScriptProvider()
        try await providerInterpreter.loadProvider(script: tenant.config.providers.joined(separator: "\n"))

        if await providerInterpreter.isClassExists(class: .userValidate) == false {
            if Constants.SECURITY.ALLOW_MISSING_PROVIDERS == false {
                Log.critical("""
                             ALLOW_MISSING_PROVIDERS is turned off. Refresh process is
                             aborted, because userValidate is not defined in \(tenant.name)
                             """, requestId: request.id
                )
                throw Abort(.serviceUnavailable, reason: "ERRORS.EXPECTED_VALUE_UNSET")
            }
            Log.error("""
                      Tenant \(tenant.name)'s userValidate provider is not present
                      Users are logged in forever! Please turn ALLOW_MISSING_PROVIDERS
                      off.
                      """, requestId: request.id)
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
        if try await providerInterpreter.getValue(class: .userValidate, property: "isValid") == true {
            return true
        }
        Log.info(
            "Cannot refresh token for user \(username), because of invalidation",
            requestId: request.id
        )
        return false
    }
}
