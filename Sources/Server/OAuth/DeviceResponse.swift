import Foundation
import Vapor

struct DeviceResponse: Codable {
    /// This is a long string that the device will use to eventually exchange for an access token
    let device_code: String

    /// This is the URL the user needs to enter into their phone to start logging in
    let verification_uri: URL

    /// This is the text the user will enter at the URL above
    let user_code: String

    /// The number of seconds that this set of values is valid. After this amount of time, the device_code and user_code will expire and the device will have to start over
    let expires_in: TimeInterval

    /// The number of seconds the device should wait between polling to see if the user has finished logging in
    let interval: TimeInterval
}

extension DeviceResponse: Content {

}
