import Foundation
import Vapor

/// Middleware that sets the jwt from the cookie into request and response header to each call
///
final class TokenToHeaderMiddleware: Middleware {

    /// Implement vapor middleware to set cookie value into headers
    ///
    /// - Parameters:
    ///   - request: The current request
    ///   - next: Responder next in chain
    /// - Returns: A future response
    ///
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {

        /// set token from cookie into headers if not set in request
        if request.headers.bearerAuthorization == nil {
            if let token = request.cookies[Constants.COOKIE.NAME]?.string {
                Log.debug("Set request bearer.", request: request)
                request.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
        }

        /// set token from cookie into headers if not set in response
        return next.respond(to: request).map { response in
            if let token = request.cookies[Constants.COOKIE.NAME]?.string {
                Log.debug("Set response bearer.", request: request)
                response.headers.bearerAuthorization = BearerAuthorization(token: token)
            }
            return response
        }
    }

}
