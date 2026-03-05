import Foundation
import Vapor

/// Request body for the Device Authorization endpoint (RFC 8628, Section 3.1).
///
/// The device posts this to `POST /oauth/device_authorization` to initiate a device flow.
///
/// ## Example
///
/// ```
/// POST /oauth/device_authorization
/// Content-Type: application/x-www-form-urlencoded
///
/// client_id=9095A4F2-35B2-48B1-A325-309CA324B97E&scope=openid+profile
/// ```
struct DeviceAuthorizationRequest: Content, ClientIdProtocol, Sendable {
    var client_id: String
    var scope: String?
}
