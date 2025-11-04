import Foundation

/// Errors that can occur during token creation and validation.
///
/// These errors represent failures in token lifecycle operations that prevent
/// successful token generation or processing.
///
/// ## Error Cases
///
/// - ``CALCULATE_TIME``: Failed to calculate token expiration
/// - ``NO_PAYLOAD``: No payload found in authentication session
///
/// ## Usage
///
/// ```swift
/// do {
///     let token = try Token(payload: userPayload, ...)
/// } catch TokenError.CALCULATE_TIME {
///     // Handle time calculation error
/// } catch TokenError.NO_PAYLOAD {
///     // Handle missing payload error
/// }
/// ```
///
/// - SeeAlso: ``Token``
enum TokenError: Error {
    /// Failed to calculate the expiration time.
    ///
    /// This error occurs when the calendar date calculation for token expiration fails,
    /// typically due to invalid date arithmetic or system time issues.
    ///
    /// ## Common Causes
    /// - System clock issues
    /// - Invalid TTL values
    /// - Calendar arithmetic overflow
    case CALCULATE_TIME

    /// No payload found in the authentication session.
    ///
    /// This error indicates that an operation requiring a payload (such as token refresh)
    /// was attempted on a session without valid payload data.
    ///
    /// ## Common Causes
    /// - Attempting to create a token without user information
    /// - Expired or invalid authentication session
    /// - Corrupted session data
    case NO_PAYLOAD
}
