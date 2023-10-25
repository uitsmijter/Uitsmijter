import Foundation

/// Represents an Error that is send back to the user if something bad happens
struct ResponseError: Codable {
    /// Error status code
    let status: Int?

    /// Is a error occurred the `error` property is set to `true`, otherwise it's `false`
    let error: Bool

    /// The `reason` property contains a string that describes why this error happens. If `error` is set to `false` then
    /// this is a special case and the reason describes why the **expected error** does not occur.
    let reason: String

    /// Last request user information
    let requestInfo: RequestInfo?

    /// Uitsmijter base url for assets
    var baseurl: String = Constants.PUBLIC_DOMAIN
}
