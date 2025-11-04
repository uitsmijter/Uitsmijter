import Foundation
import Vapor

// MARK: - Storage Key

/// Storage key for accessing ``RequestInfo`` in Vapor's request storage.
struct RequestInfoKey: StorageKey {
    typealias Value = RequestInfo
}

// MARK: - Request Extension

/// Extension to add additional request information to Vapor requests.
extension Request {
    /// Additional information about the request for error handling and debugging.
    ///
    /// This property stores contextual information that can be included in error
    /// responses or logged for debugging purposes.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Setting request info
    /// req.requestInfo = RequestInfo(description: "OAuth authorization request")
    ///
    /// // Using in error response
    /// return ResponseError(
    ///     status: 400,
    ///     error: true,
    ///     reason: "Invalid request",
    ///     requestInfo: req.requestInfo
    /// )
    /// ```
    ///
    /// - SeeAlso: ``RequestInfo``
    /// - SeeAlso: ``ResponseError``
    var requestInfo: RequestInfo? {
        get {
            storage[RequestInfoKey.self]
        }
        set {
            storage[RequestInfoKey.self] = newValue
        }
    }
}
