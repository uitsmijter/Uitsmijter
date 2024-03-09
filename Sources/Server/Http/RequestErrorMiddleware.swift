import Vapor

public final class RequestErrorMiddleware: AsyncMiddleware {

    /// Create a default `RequestErrorMiddleware`. Logs errors
    /// and converts `Error` to `Response` based on conformance to `AbortError` and `Debuggable`.
    ///
    /// - parameters:
    ///     - environment: The environment to respect when presenting errors.
    public static func `default`(environment: Environment) -> RequestErrorMiddleware {
        .init { req, error in
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
    private let closure: (Request, Error) async -> Response

    /// Create a new `ErrorMiddleware`.
    ///
    /// - parameters:
    ///     - closure: Error-handling closure. Converts `Error` to `Response`.
    public init(_ closure: @escaping (Request, Error) async -> Response) {
        self.closure = closure
    }

    /// Respond to the request
    ///
    /// - Parameters:
    ///   - request: Vapor request
    ///   - next: next hob
    /// - Returns: A `Response`
    /// - Throws:
    public func respond(
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
