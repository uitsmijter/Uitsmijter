import Foundation
import Logger

// MARK: - Client Validation Methods

/// Security validation methods for OAuth redirect URIs and referers.
///
/// These methods validate that redirect URIs and referers match the client's
/// configured allowlists, preventing open redirect vulnerabilities.
///
/// ## Topics
///
/// ### Validation Methods
/// - ``checkedRedirect(for:)``
/// - ``checkedReferer(for:)``
///
/// - SeeAlso: ``ClientSpec/redirect_urls``
/// - SeeAlso: ``ClientSpec/referrers``
public extension Client {

    /// Validates that a redirect URI is allowed for this client.
    ///
    /// This method checks the requested redirect URI against the client's configured
    /// `redirect_urls` patterns. Each pattern is treated as a regular expression.
    ///
    /// ## Security
    ///
    /// - Prevents open redirect attacks
    /// - Special case: `/authorize?...` is always allowed for OAuth flow
    /// - Patterns are matched using regular expressions
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Client configuration
    /// redirect_urls:
    ///   - "https://app\\.example\\.com/.*"
    ///   - "https://[a-z]+\\.example\\.com/callback"
    ///
    /// // Valid redirects
    /// try client.checkedRedirect(for: authRequest) // OK
    ///
    /// // Invalid redirect throws error
    /// try client.checkedRedirect(for: maliciousRequest) // Throws
    /// ```
    ///
    /// - Parameter objectWithRedirect: An object containing the redirect URI to validate
    /// - Returns: The validated redirect URI string
    /// - Throws: ``ClientError/illegalRedirect(redirect:)`` if the URI doesn't match allowlist
    ///
    /// - SeeAlso: ``RedirectUriProtocol``
    /// - SeeAlso: ``ClientSpec/redirect_urls``
    @discardableResult
    func checkedRedirect(for objectWithRedirect: RedirectUriProtocol) throws -> String {
        // check redirect_uri / if set, must be match
        let redirect = objectWithRedirect.redirect_uri.absoluteString

        // oauth authorize redirects to "/authorize?..." - we allow this
        if redirect.starts(with: "/authorize?") {
            return redirect
        }

        let passedRedirectRules = self.config.redirect_urls.compactMap { allowedRedirectionPattern -> Bool in
            let result = redirect.range(
                of: allowedRedirectionPattern,
                options: .regularExpression
            )
            Log.debug("Check \(redirect) | \(allowedRedirectionPattern): \(result?.description ?? "nil")")
            return result != nil
        }

        if passedRedirectRules.contains(where: { $0 != false }) == false {
            throw ClientError.illegalRedirect(redirect: redirect)
        }

        return redirect
    }

    /// Validates that an HTTP referer is allowed for this client.
    ///
    /// This method checks the referer header against the client's optional
    /// `referrers` patterns. Each pattern is treated as a regular expression.
    ///
    /// ## Usage
    ///
    /// This is typically used during authorization to ensure requests originate
    /// from expected domains.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Client configuration
    /// referrers:
    ///   - "https://trusted\\.example\\.com"
    ///   - "https://app\\.example\\.com"
    ///
    /// // Valid referer
    /// try client.checkedReferer(for: "https://trusted.example.com") // OK
    ///
    /// // Invalid referer throws error
    /// try client.checkedReferer(for: "https://evil.com") // Throws
    /// ```
    ///
    /// - Parameter referer: The HTTP referer header value to validate
    /// - Returns: The validated referer string
    /// - Throws: ``ClientError/illegalReferer(referer:)`` if referer doesn't match allowlist
    ///
    /// - SeeAlso: ``ClientSpec/referrers``
    @discardableResult
    func checkedReferer(for referer: String) throws -> String {
        let passedRefererRules = self.config.referrers?.compactMap { allowedRefererPattern -> Bool in
            let result = referer.range(
                of: allowedRefererPattern,
                options: .regularExpression
            )
            Log.debug("Check \(referer) | \(allowedRefererPattern): \(result?.description ?? "nil")")
            return result != nil
        } ?? [false]

        if passedRefererRules.contains(where: { $0 != false }) == false {
            throw ClientError.illegalReferer(referer: referer)
        }

        return referer
    }
}
