import Foundation
import Vapor

/// Extends a `HTTPCookie` to set a cookie with some default values
///
extension HTTPCookies.Value {

    /// Returns a default cookie for this project
    ///
    /// - Parameters:
    ///   - expires: When the cookie should be expired
    ///   - content: Teh content of the cookie
    /// - Returns: Returns a new HTTPCookies.Value.
    ///
    static func defaultCookie(expires: Date, withContent content: String) -> HTTPCookies.Value {
        var cookie = HTTPCookies.Value(string: content,
                isSecure: Constants.TOKEN.isSecure,
                isHTTPOnly: Constants.TOKEN.isHTTPOnly,
                sameSite: Constants.TOKEN.sameSite
        )
        cookie.expires = expires
        cookie.maxAge = expires.millisecondsSinceNow / 1000
        cookie.path = "/"
        return cookie
    }
}
