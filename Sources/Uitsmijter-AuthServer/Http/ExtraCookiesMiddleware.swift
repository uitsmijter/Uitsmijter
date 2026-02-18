import Foundation
import Vapor

/// Storage key for extra Set-Cookie header values that must bypass Vapor's cookie dictionary.
///
/// Vapor's `response.cookies` is backed by a `[String: Value]` dictionary, which cannot
/// represent multiple cookies with the same name but different domains. The
/// `SessionsMiddleware` triggers a full get/set cycle on this dictionary when clearing
/// session cookies, collapsing any manually added duplicate-name headers.
///
/// Controllers store raw Set-Cookie strings in this key, and ``ExtraCookiesMiddleware``
/// appends them to the response **after** the session middleware has finished.
struct ExtraCookiesKey: StorageKey {
    typealias Value = [String]
}

extension Request {
    /// Raw Set-Cookie header values to append after session middleware processing.
    var extraSetCookieHeaders: [String] {
        get { storage[ExtraCookiesKey.self] ?? [] }
        set { storage[ExtraCookiesKey.self] = newValue }
    }
}

/// Middleware that appends extra Set-Cookie headers after the session middleware runs.
///
/// This middleware must be registered **before** `SessionsMiddleware` in the chain so that
/// it wraps around it. On the response path it adds any Set-Cookie values that controllers
/// stored in ``Request/extraSetCookieHeaders``.
///
/// ## Why this exists
///
/// When a logout must invalidate cookies on multiple domains (e.g. `.ops.example.com` and
/// `login.ops.example.com`), two `Set-Cookie` headers with the same cookie name but
/// different `Domain` attributes are required. Vapor's `HTTPCookies` dictionary collapses
/// these into one entry. The `SessionsMiddleware` inadvertently triggers this collapse
/// when it clears the session cookie via `response.cookies[name] = .expired`.
///
/// By storing the extra headers in request storage and appending them outside the session
/// middleware, we ensure both cookies reach the browser.
final class ExtraCookiesMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        for header in request.extraSetCookieHeaders {
            response.headers.add(name: "Set-Cookie", value: header)
        }
        return response
    }
}
