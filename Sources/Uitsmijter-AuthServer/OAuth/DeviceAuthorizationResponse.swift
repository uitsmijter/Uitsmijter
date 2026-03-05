import Foundation
import Vapor

// swiftlint:disable:next type_name
/// Response from the Device Authorization endpoint (RFC 8628, Section 3.2).
///
/// ## Example Response
///
/// ```json
/// {
///   "device_code": "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
///   "user_code": "WDJB-MJHT",
///   "verification_uri": "https://example.com/activate",
///   "expires_in": 1800,
///   "interval": 5
/// }
/// ```
struct DeviceAuthorizationResponse: Content, Sendable {
    /// The device verification code, used by the device to poll the token endpoint.
    let device_code: String

    /// The end-user verification code shown on the device screen.
    let user_code: String

    /// The end-user verification URI on the authorization server.
    let verification_uri: String

    /// The lifetime in seconds of the `device_code` and `user_code`.
    let expires_in: Int

    /// The minimum amount of time in seconds that the client should wait between polling requests.
    let interval: Int
}
