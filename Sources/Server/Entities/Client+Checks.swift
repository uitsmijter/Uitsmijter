import Foundation

extension Client {

    /// Returns the requested redirect when it is allowed, otherwise throws an error
    ///
    /// - Parameters:
    ///   - objectWithRedirect: Request type of AuthRequestProtocol
    /// - Returns: A String of the requested and allowed redirect url
    /// - Throws: An error when the requested redirect url is not allowed
    ///
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

    /// Returns the given referer when it is allowed, otherwise throws an error
    ///
    /// - Parameters:
    ///   - referer: String of the referer
    /// - Returns: the given referer
    /// - Throws: An error when the requested redirect url is not allowed
    ///
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
