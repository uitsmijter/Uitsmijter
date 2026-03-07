import Foundation
import Vapor

/// Token request for the Device Authorization Grant (RFC 8628, Section 3.4).
///
/// The device posts this to `POST /token` to poll for an access token after
/// the user has authorized the device at the activation endpoint.
///
/// ## Polling Behavior
///
/// The device polls at the interval returned by the device authorization response
/// (default: 5 seconds). The server responds with one of:
/// - `200 OK` with tokens once the user has authorized
/// - `400 authorization_pending` while the user hasn't completed authorization yet
/// - `400 slow_down` if polling too frequently (device must increase interval)
/// - `400 access_denied` if the user denied authorization
///
/// ## Example
///
/// ```
/// POST /token
/// Content-Type: application/x-www-form-urlencoded
///
/// grant_type=device_code
///   &device_code=GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS
///   &client_id=9095A4F2-35B2-48B1-A325-309CA324B97E
/// ```
struct DeviceTokenRequest: TokenRequestProtocol, Sendable {

    /// The grant type. Must be `device_code`.
    var grant_type: GrantTypes

    /// The client identifier.
    var client_id: String

    /// The client secret for confidential clients.
    var client_secret: String?

    /// The device verification code obtained from the device authorization response.
    let device_code: String
}
