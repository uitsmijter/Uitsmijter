import Foundation
import Vapor

// MARK: - HTTPCookies Extension

/// Extends Vapor's `HTTPCookies.Value` to create cookies with application defaults.
///
/// This extension provides convenient methods for creating HTTP cookies with
/// security settings defined in ``CookieConfiguration``.
///
/// ## Topics
///
/// ### Creating Cookies
/// - ``defaultCookie(expires:withContent:)``
/// - ``cookie(from:)``
///
/// - SeeAlso: ``CookieConfiguration``, ``CookieSettings``
extension HTTPCookies.Value {

    /// Creates a cookie with default security settings.
    ///
    /// This method creates an HTTP cookie using the application's default security
    /// configuration from ``CookieConfiguration``.
    ///
    /// - Parameters:
    ///   - expires: When the cookie should expire
    ///   - content: The content/value of the cookie
    /// - Returns: A new `HTTPCookies.Value` configured with application defaults
    ///
    /// ## Example
    ///
    /// ```swift
    /// let expiryDate = Date().addingTimeInterval(3600) // 1 hour
    /// let cookie = HTTPCookies.Value.defaultCookie(
    ///     expires: expiryDate,
    ///     withContent: "session_token_value"
    /// )
    /// ```
    ///
    /// - SeeAlso: ``cookie(from:)``
    static func defaultCookie(expires: Date, withContent content: String) -> HTTPCookies.Value {
        let sameSite: HTTPCookies.SameSitePolicy
        switch CookieConfiguration.sameSitePolicy {
        case .strict: sameSite = .strict
        case .lax: sameSite = .lax
        case .noRestriction: sameSite = .none
        }

        var cookie = HTTPCookies.Value(
            string: content,
            isSecure: CookieConfiguration.isSecure,
            isHTTPOnly: CookieConfiguration.isHTTPOnly,
            sameSite: sameSite
        )
        cookie.expires = expires
        cookie.maxAge = expires.millisecondsSinceNow / 1000
        cookie.path = CookieConfiguration.defaultPath
        return cookie
    }

    /// Creates a Vapor HTTPCookies.Value from framework-agnostic cookie settings.
    ///
    /// This method converts ``CookieSettings`` to Vapor's `HTTPCookies.Value`,
    /// allowing the use of framework-independent cookie configuration.
    ///
    /// - Parameter settings: The cookie settings to convert
    /// - Returns: A new `HTTPCookies.Value` instance
    ///
    /// ## Example
    ///
    /// ```swift
    /// let settings = CookieSettings.default(
    ///     content: "token",
    ///     expires: Date().addingTimeInterval(3600)
    /// )
    /// let cookie = HTTPCookies.Value.cookie(from: settings)
    /// ```
    ///
    /// - SeeAlso: ``CookieSettings``
    static func cookie(from settings: CookieSettings) -> HTTPCookies.Value {
        let sameSite: HTTPCookies.SameSitePolicy
        switch settings.sameSite {
        case .strict: sameSite = .strict
        case .lax: sameSite = .lax
        case .noRestriction: sameSite = .none
        }

        var cookie = HTTPCookies.Value(
            string: settings.content,
            isSecure: settings.isSecure,
            isHTTPOnly: settings.isHTTPOnly,
            sameSite: sameSite
        )
        cookie.expires = settings.expires
        cookie.maxAge = settings.maxAge
        cookie.path = settings.path
        return cookie
    }
}
