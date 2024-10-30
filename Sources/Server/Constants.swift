import Foundation
import Vapor

/// Stores constants for the project that is used on multiple places
struct Constants {
    static let APPLICATION = "Uitsmijter"
    static let MAJOR_VERSION = 1
    static let isRelease = Application().environment.isRelease

    static let PUBLIC_DOMAIN = Environment.get("PUBLIC_DOMAIN") ?? "localhost:8080"

    /// The cookie that is written to the client
    struct COOKIE {
        static let NAME = "\(Constants.APPLICATION.lowercased())-sso"
        static let EXPIRATION_DAYS = Int(Environment.get("COOKIE_EXPIRATION_IN_DAYS") ?? "7") ?? 7
    }

    /// Token cookie settings
    struct TOKEN {
        static let isSecure = Bool(Environment.get("SECURE") ?? "false") ?? false
        static let isHTTPOnly = true
        /// Strict
        /// means that the browser sends the cookie only for same-site requests, that is, requests originating from
        /// the same site that set the cookie. If a request originates from a different domain or scheme (even with the
        /// same domain), no cookies with the SameSite=Strict attribute are sent.
        ///
        /// Lax
        /// means that the cookie is not sent on cross-site requests, such as on requests to load images or frames,
        /// but is sent when a user is navigating to the origin site from an external site (for example, when following
        /// a link). This is the default behavior if the SameSite attribute is not specified.
        ///
        /// None
        /// means that the browser sends the cookie with both cross-site and same-site requests. The Secure attribute
        /// must also be set when setting this value, like so SameSite=None; Secure
        static let sameSite: Vapor.HTTPCookies.SameSitePolicy = .strict
        static let LENGTH = 16
        static let EXPIRATION_HOURS = Int(Environment.get("TOKEN_EXPIRATION_IN_HOURS") ?? "2") ?? 2
        static let REFRESH_EXPIRATION_IN_HOURS = Int(
                Environment.get("TOKEN_REFRESH_EXPIRATION_IN_HOURS") ?? "720"
        ) ?? 720
    }

    // Authentication Code settings

    struct AUTHCODE {
        static let TimeToLive: Int64 = 10 * 60
    }

    /// Settings for script providers
    struct PROVIDER {
        static let SCRIPT_TIMEOUT = 30
    }

    /// Runtime settings
    struct RUNTIME {
        static let SUPPORT_KUBERNETES_CRD: Bool = Bool(Environment.get("SUPPORT_KUBERNETES_CRD") ?? "false") ?? false
        static let SCOPED_KUBERNETES_CRD: Bool = Bool(Environment.get("SCOPED_KUBERNETES_CRD") ?? "false") ?? false
        static let UITSMIJTER_NAMESPACE: String = Environment.get("UITSMIJTER_NAMESPACE") ?? ""
    }

    // Security
    struct SECURITY {
        static let DISPLAY_VERSION: Bool = Bool(Environment.get("DISPLAY_VERSION") ?? "true") ?? true

        /// Missing providers are allowed by default in development mode if not set otherwise via environment variables.
        /// Attention: This could result in a user that is always being logged in because the UserValidationProvider was
        /// not specified.
        /// In production the default is always off, but could also be overwritten by environment variables.
        /// This might change in future versions.
        static var ALLOW_MISSING_PROVIDERS: Bool {
            get {
                let defaultValue = Constants.isRelease == true ? false : true
                return Bool(Environment.get("ALLOW_MISSING_PROVIDERS") ?? "\(defaultValue.description)") ?? defaultValue
            }
        }
    }
}
