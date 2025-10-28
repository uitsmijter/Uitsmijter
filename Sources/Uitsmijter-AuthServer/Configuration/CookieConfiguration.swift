import Foundation

// MARK: - Cookie Configuration

/// Configuration settings for HTTP cookies.
///
/// This structure provides centralized configuration for cookie security
/// and behavior settings used throughout the application.
///
/// ## Topics
///
/// ### Security Settings
/// - ``isSecure``
/// - ``isHTTPOnly``
/// - ``sameSitePolicy``
///
/// ### Cookie Parameters
/// - ``defaultPath``
///
/// - SeeAlso: ``CookieSameSitePolicy``
struct CookieConfiguration {

    /// Indicates whether cookies should only be sent over HTTPS connections.
    ///
    /// When `true`, cookies will only be transmitted over secure (HTTPS) connections.
    /// This helps prevent man-in-the-middle attacks.
    ///
    /// - Environment: `SECURE`
    /// - Default: `false`
    static let isSecure: Bool = {
        guard let value = ProcessInfo.processInfo.environment["SECURE"] else {
            return false
        }
        return Bool(value) ?? false
    }()

    /// Indicates whether cookies should be HTTP-only.
    ///
    /// When `true`, cookies cannot be accessed via JavaScript (document.cookie).
    /// This helps prevent XSS (Cross-Site Scripting) attacks.
    ///
    /// - Default: `true`
    static let isHTTPOnly: Bool = true

    /// The SameSite policy for cookies.
    ///
    /// Controls when cookies are sent with cross-site requests.
    ///
    /// - Default: `.strict`
    /// - SeeAlso: ``CookieSameSitePolicy``
    static let sameSitePolicy: CookieSameSitePolicy = .strict

    /// The default path for cookies.
    ///
    /// Specifies the URL path that must exist in the requested URL for the
    /// browser to send the cookie.
    ///
    /// - Default: `"/"`
    static let defaultPath: String = "/"
}

// MARK: - SameSite Policy

/// Cookie SameSite attribute values.
///
/// The SameSite attribute controls whether cookies are sent with cross-site requests,
/// providing protection against Cross-Site Request Forgery (CSRF) attacks.
///
/// ## Topics
///
/// ### Policy Values
/// - ``strict``
/// - ``lax``
/// - ``noRestriction``
enum CookieSameSitePolicy: String, Sendable {
    /// Cookies are only sent for same-site requests.
    ///
    /// The browser sends cookies only for same-site requests, that is,
    /// requests originating from the same site that set the cookie.
    ///
    /// - Note: Provides the strongest CSRF protection
    case strict = "Strict"

    /// Cookies are sent with top-level navigations from external sites.
    ///
    /// The cookie is not sent on cross-site requests (such as loading images
    /// or frames), but is sent when a user navigates to the origin site from
    /// an external site (e.g., following a link).
    ///
    /// - Note: This is the default behavior if SameSite is not specified
    case lax = "Lax"

    /// Cookies are sent with both cross-site and same-site requests.
    ///
    /// The browser sends cookies with both cross-site and same-site requests.
    ///
    /// - Important: The `Secure` attribute must also be set when using this value
    case noRestriction = "None"
}

// MARK: - Cookie Builder

/// A structure for building HTTP cookie configurations.
///
/// Provides a type-safe way to create cookie settings that can be used
/// with various HTTP frameworks.
///
/// ## Example
///
/// ```swift
/// let settings = CookieSettings(
///     content: "token_value",
///     expires: Date().addingTimeInterval(3600),
///     isSecure: CookieConfiguration.isSecure,
///     isHTTPOnly: CookieConfiguration.isHTTPOnly,
///     sameSite: CookieConfiguration.sameSitePolicy,
///     path: CookieConfiguration.defaultPath
/// )
/// ```
struct CookieSettings {
    /// The cookie value/content
    public let content: String

    /// When the cookie expires
    public let expires: Date

    /// Whether the cookie requires HTTPS
    public let isSecure: Bool

    /// Whether the cookie is HTTP-only (not accessible via JavaScript)
    public let isHTTPOnly: Bool

    /// The SameSite policy
    public let sameSite: CookieSameSitePolicy

    /// The URL path for the cookie
    public let path: String

    /// The max-age value in seconds
    public var maxAge: Int {
        expires.millisecondsSinceNow / 1000
    }

    /// Creates a new cookie settings instance.
    ///
    /// - Parameters:
    ///   - content: The cookie value
    ///   - expires: The expiration date
    ///   - isSecure: Whether to require HTTPS (defaults to ``CookieConfiguration/isSecure``)
    ///   - isHTTPOnly: Whether to be HTTP-only (defaults to ``CookieConfiguration/isHTTPOnly``)
    ///   - sameSite: The SameSite policy (defaults to ``CookieConfiguration/sameSitePolicy``)
    ///   - path: The URL path (defaults to ``CookieConfiguration/defaultPath``)
    public init(
        content: String,
        expires: Date,
        isSecure: Bool = CookieConfiguration.isSecure,
        isHTTPOnly: Bool = CookieConfiguration.isHTTPOnly,
        sameSite: CookieSameSitePolicy = CookieConfiguration.sameSitePolicy,
        path: String = CookieConfiguration.defaultPath
    ) {
        self.content = content
        self.expires = expires
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
        self.path = path
    }

    /// Creates a cookie settings instance with default security settings.
    ///
    /// - Parameters:
    ///   - content: The cookie value
    ///   - expires: The expiration date
    /// - Returns: A new cookie settings instance with default security values
    public static func `default`(content: String, expires: Date) -> CookieSettings {
        CookieSettings(content: content, expires: expires)
    }
}
