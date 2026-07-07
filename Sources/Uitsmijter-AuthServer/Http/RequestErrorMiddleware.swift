import Vapor
import Logger

final class RequestErrorMiddleware: AsyncMiddleware {

    /// Create a default `RequestErrorMiddleware`. Logs errors
    /// and converts `Error` to `Response` based on conformance to `AbortError` and `Debuggable`.
    ///
    /// - parameters:
    ///     - environment: The environment to respect when presenting errors.
    static func `default`(environment: Environment) -> RequestErrorMiddleware {
        .init { req, error in
            // Standard OAuth 2.0 errors (RFC 6749 §5.2 / RFC 8628 §3.5) are rendered
            // in their own `{"error": "...", "error_description": "..."}` shape so that
            // conformant OAuth2 client libraries can interpret them.
            if let oauth = error as? OAuthError {
                Log.info("OAuth error on \(req.url.path): \(oauth.code)")
                let response = Response(status: oauth.status)
                response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
                response.headers.replaceOrAdd(name: .cacheControl, value: "no-store")
                do {
                    response.body = try .init(
                        data: JSONEncoder().encode(
                            OAuthErrorBody(error: oauth.code, error_description: oauth.errorDescription)
                        ),
                        byteBufferAllocator: req.byteBufferAllocator
                    )
                } catch {
                    response.body = .init(string: "{\"error\":\"\(oauth.code)\"}")
                }
                return response
            }

            // variables to determine
            let status: HTTPResponseStatus
            let reason: String
            let headers: HTTPHeaders

            // inspect the error type
            switch error {
            case let abort as AbortError:
                // this is an abort error, we should use its status, reason, and headers
                reason = abort.reason
                status = abort.status
                headers = abort.headers
            default:
                // if not release mode, and error is debuggable, provide debug info
                // otherwise, deliver a generic 500 to avoid exposing any sensitive error info
                reason = environment.isRelease
                    ? "Something went wrong."
                    : String(describing: error)
                status = .internalServerError
                headers = [:]
            }

            // Report the error to logger.
            Log.info("Response error on \(req.url.path): \(error.localizedDescription)")

            // create a Response with appropriate status
            let response = Response(status: status, headers: headers)

            // attempt to serialize the error to json
            do {
                let errorResponse = ResponseError(
                    status: status.code.intValue,
                    error: true,
                    reason: reason,
                    requestInfo: req.requestInfo
                )
                if req.headers.accept.contains(where: { $0.mediaType == HTTPMediaType.html }) {
                    let view: View = try await req.view.render(
                        Template.getPath(page: "error", request: req),
                        errorResponse
                    )
                    response.body = try await view.encodeResponse(status: status, for: req).body
                    response.headers.replaceOrAdd(name: .contentType, value: "text/html; charset=utf-8")
                } else {
                    response.body = try .init(
                        data: JSONEncoder().encode(errorResponse),
                        byteBufferAllocator: req.byteBufferAllocator
                    )
                    response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
                }

            } catch {
                response.body = .init(string: "Oops: \(error)", byteBufferAllocator: req.byteBufferAllocator)
                response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
            }
            return response
        }
    }

    /// Error-handling closure.
    private let closure: (@Sendable (Request, Error) async -> Response)

    /// Create a new `ErrorMiddleware`.
    ///
    /// - parameters:
    ///     - closure: Error-handling closure. Converts `Error` to `Response`.
    init(_ closure: @Sendable @escaping (Request, Error) async -> Response) {
        self.closure = closure
    }

    /// Respond to the request
    ///
    /// - Parameters:
    ///   - request: Vapor request
    ///   - next: next hob
    /// - Returns: A `Response`
    /// - Throws:
    func respond(
        to request: Vapor.Request,
        chainingTo next: Vapor.AsyncResponder
    ) async throws -> Vapor.Response {
        var response: Response
        do {
            response = try await next.respond(to: request)
        } catch {
            response = await closure(request, error)
        }
        return response
    }
}
