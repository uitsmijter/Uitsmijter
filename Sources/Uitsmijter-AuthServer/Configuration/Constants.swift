import Foundation
import Vapor

// MARK: - Application Constants

/// Global constants and configuration values for the Uitsmijter authorization server.
///
/// This structure centralizes all application-wide constants, environment-based settings,
/// and configuration defaults. Values are loaded from environment variables when available,
/// with sensible fallbacks.
///
/// ## Configuration Sources
///
/// - Environment variables (preferred for deployment)
/// - Hardcoded defaults (for development)
///
/// ## Topics
///
/// ### Application Info
/// - ``APPLICATION``
/// - ``MAJOR_VERSION``
/// - ``isRelease``
/// - ``PUBLIC_DOMAIN``
///
/// ### Configuration Groups
/// - ``COOKIE``
/// - ``TOKEN``
/// - ``AUTHCODE``
/// - ``PROVIDER``
/// - ``RUNTIME``
/// - ``SECURITY``
///
/// - SeeAlso: ``CookieConfiguration``
/// - SeeAlso: ``RuntimeConfiguration``
struct Constants {
    /// The application name.
    static let APPLICATION = "Uitsmijter"

    /// The major version number.
    static let MAJOR_VERSION = 1

    /// Indicates if the application is running in production mode.
    ///
    /// Set to `true` when the `ENVIRONMENT` variable equals "production".
    static let isRelease = ProcessInfo.processInfo.environment["ENVIRONMENT"] == "production"

    /// The public domain where the authorization server is accessible.
    ///
    /// - Environment: `PUBLIC_DOMAIN`
    /// - Default: "localhost:8080"
    static let PUBLIC_DOMAIN = Environment.get("PUBLIC_DOMAIN") ?? "localhost:8080"

    // MARK: - Cookie Settings

    /// Cookie configuration constants.
    ///
    /// Settings for the SSO cookie written to client browsers.
    ///
    /// ## Topics
    ///
    /// ### Properties
    /// - ``NAME``
    /// - ``EXPIRATION_DAYS``
    struct COOKIE {
        /// The name of the SSO cookie.
        ///
        /// Constructed as: `{application-name}-sso`
        static let NAME = "\(Constants.APPLICATION.lowercased())-sso"

        /// The number of days until the cookie expires.
        ///
        /// - Environment: `COOKIE_EXPIRATION_IN_DAYS`
        /// - Default: 7 days
        static let EXPIRATION_DAYS = Int(Environment.get("COOKIE_EXPIRATION_IN_DAYS") ?? "7") ?? 7
    }

    // MARK: - Token Settings

    /// JWT token and cookie security settings.
    ///
    /// Configuration for token generation, expiration, and security policies.
    ///
    /// ## Topics
    ///
    /// ### Security Settings
    /// - ``isSecure``
    /// - ``isHTTPOnly``
    /// - ``sameSite``
    ///
    /// ### Token Properties
    /// - ``LENGTH``
    /// - ``EXPIRATION_HOURS``
    /// - ``REFRESH_EXPIRATION_IN_HOURS``
    struct TOKEN {
        /// Indicates if cookies should only be sent over HTTPS.
        ///
        /// - Environment: `SECURE`
        /// - Default: `false`
        static let isSecure = Bool(Environment.get("SECURE") ?? "false") ?? false

        /// Indicates if cookies should be HTTP-only (not accessible via JavaScript).
        ///
        /// This helps prevent XSS attacks by blocking JavaScript access to cookies.
        static let isHTTPOnly = true

        /// The SameSite cookie policy.
        ///
        /// ## Policy Modes
        ///
        /// - **Strict**: Cookies only sent for same-site requests
        /// - **Lax**: Cookies sent for top-level navigation from external sites
        /// - **None**: Cookies sent with all requests (requires Secure flag)
        ///
        /// - Default: `.strict`
        static let sameSite: Vapor.HTTPCookies.SameSitePolicy = .strict

        /// The length of generated tokens in bytes.
        static let LENGTH = 16

        /// The number of hours until JWT tokens expire.
        ///
        /// - Environment: `TOKEN_EXPIRATION_IN_HOURS`
        /// - Default: 2 hours
        static let EXPIRATION_HOURS = Int(Environment.get("TOKEN_EXPIRATION_IN_HOURS") ?? "2") ?? 2

        /// The number of hours until refresh tokens expire.
        ///
        /// - Environment: `TOKEN_REFRESH_EXPIRATION_IN_HOURS`
        /// - Default: 720 hours (30 days)
        static let REFRESH_EXPIRATION_IN_HOURS = Int(
            Environment.get("TOKEN_REFRESH_EXPIRATION_IN_HOURS") ?? "720"
        ) ?? 720
    }

    // MARK: - Authorization Code Settings

    /// OAuth2 authorization code configuration.
    ///
    /// Settings for the temporary authorization codes generated during the OAuth flow.
    ///
    /// ## Topics
    ///
    /// ### Properties
    /// - ``TimeToLive``
    struct AUTHCODE {
        /// Time-to-live for authorization codes in seconds.
        ///
        /// Authorization codes expire after 10 minutes (600 seconds) for security.
        static let TimeToLive: Int64 = 10 * 60
    }

    // MARK: - Provider Settings

    /// JavaScript provider execution settings.
    ///
    /// Configuration for the JavaScript execution engine used by authentication providers.
    ///
    /// ## Topics
    ///
    /// ### Properties
    /// - ``SCRIPT_TIMEOUT``
    struct PROVIDER {
        /// Maximum execution time for provider scripts in seconds.
        ///
        /// Scripts that exceed this timeout will be terminated.
        static let SCRIPT_TIMEOUT = 30
    }

    // MARK: - Runtime Settings

    /// Runtime environment configuration.
    ///
    /// Settings that control runtime behavior, particularly Kubernetes integration.
    ///
    /// ## Topics
    ///
    /// ### Kubernetes Support
    /// - ``SUPPORT_KUBERNETES_CRD``
    /// - ``SCOPED_KUBERNETES_CRD``
    /// - ``UITSMIJTER_NAMESPACE``
    struct RUNTIME {
        /// Enables Kubernetes Custom Resource Definition (CRD) support.
        ///
        /// - Environment: `SUPPORT_KUBERNETES_CRD`
        /// - Default: `false`
        static let SUPPORT_KUBERNETES_CRD: Bool = Bool(Environment.get("SUPPORT_KUBERNETES_CRD") ?? "false") ?? false

        /// Limits CRD watching to a specific namespace.
        ///
        /// - Environment: `SCOPED_KUBERNETES_CRD`
        /// - Default: `false`
        static let SCOPED_KUBERNETES_CRD: Bool = Bool(Environment.get("SCOPED_KUBERNETES_CRD") ?? "false") ?? false

        /// The Kubernetes namespace to watch when scoped mode is enabled.
        ///
        /// - Environment: `UITSMIJTER_NAMESPACE`
        /// - Default: `""` (empty string)
        static let UITSMIJTER_NAMESPACE: String = Environment.get("UITSMIJTER_NAMESPACE") ?? ""
    }

    // MARK: - Security Settings

    /// Security-related configuration.
    ///
    /// Settings that control security policies and behavior.
    ///
    /// ## Topics
    ///
    /// ### Properties
    /// - ``DISPLAY_VERSION``
    /// - ``ALLOW_MISSING_PROVIDERS``
    struct SECURITY {
        /// Controls whether version information is displayed publicly.
        ///
        /// - Environment: `DISPLAY_VERSION`
        /// - Default: `true`
        static let DISPLAY_VERSION: Bool = Bool(Environment.get("DISPLAY_VERSION") ?? "true") ?? true

        /// Controls whether missing provider scripts are tolerated.
        ///
        /// ## Security Warning
        ///
        /// When enabled, users without a `UserValidate` provider may remain logged in
        /// indefinitely. This is a security risk and should only be used in development.
        ///
        /// ## Default Behavior
        ///
        /// - **Development**: `true` (missing providers allowed)
        /// - **Production**: `false` (missing providers cause errors)
        ///
        /// - Environment: `ALLOW_MISSING_PROVIDERS`
        static var ALLOW_MISSING_PROVIDERS: Bool {
            get {
                let defaultValue = Constants.isRelease == true ? false : true
                return Bool(Environment.get("ALLOW_MISSING_PROVIDERS") ?? "\(defaultValue.description)") ?? defaultValue
            }
        }
    }
}
