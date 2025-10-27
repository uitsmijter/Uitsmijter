import Foundation
import Vapor

/// Extends the `AuthSession` model to redirect to a request with a code
///
extension AuthSession {

    /// Redirect the request of the AuthSession with a code
    ///
    /// - Parameter req: Vapor request
    /// - Returns: A redirection response
    ///
    func codeRedirect(to req: Request) -> Response {
        req.redirect(to: "\(redirect)?code=\(code.value)&state=\(state)")
    }
}
