import Vapor

/// A standards-compliant OAuth 2.0 error, as defined by RFC 6749 §5.2 and the
/// device-flow-specific codes in RFC 8628 §3.5.
///
/// `RequestErrorMiddleware` renders this as the JSON body
/// `{"error": "<code>", "error_description": "<text>"}` with the given HTTP status,
/// instead of Uitsmijter's generic `{"error": true, "reason": ...}` envelope.
///
/// This is the shape standard OAuth2 client libraries expect from the token
/// endpoint, so returning it lets conformant device-flow clients interpret
/// `authorization_pending` / `slow_down` / `access_denied` correctly while polling.
struct OAuthError: AbortError {
    /// Machine-readable OAuth error code, e.g. `authorization_pending`.
    let code: String

    /// Optional human-readable description (`error_description`).
    let errorDescription: String?

    /// HTTP status to return. RFC 6749 §5.2 uses `400 Bad Request` for token errors.
    let status: HTTPResponseStatus

    init(_ code: String, description: String? = nil, status: HTTPResponseStatus = .badRequest) {
        self.code = code
        self.errorDescription = description
        self.status = status
    }

    /// `AbortError` conformance — `reason` mirrors the code for logging/metrics.
    var reason: String { code }

    // MARK: - Device flow errors (RFC 8628 §3.5)

    /// The user has not yet completed authorization; the client should keep polling.
    static let authorizationPending = OAuthError(
        "authorization_pending",
        description: "The authorization request is still pending; the user has not yet completed the flow."
    )

    /// The client is polling too frequently and must increase its interval.
    static let slowDown = OAuthError(
        "slow_down",
        description: "Polling too frequently. Increase the interval between token requests."
    )

    /// The user denied the authorization request.
    static let accessDenied = OAuthError(
        "access_denied",
        description: "The user denied the authorization request."
    )

    /// The `device_code` is unknown, already used, or expired.
    static func invalidGrant(
        _ description: String = "The device_code is invalid, already used, or expired."
    ) -> OAuthError {
        OAuthError("invalid_grant", description: description)
    }
}

/// JSON body for an ``OAuthError`` response (RFC 6749 §5.2).
struct OAuthErrorBody: Content {
    let error: String
    let error_description: String? // swiftlint:disable:this identifier_name
}
