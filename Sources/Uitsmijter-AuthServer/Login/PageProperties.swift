import Foundation

/// Every page that the authorisation server renders for the user a set of parameters can be passed to the template.
///
/// - Parameters:
///     - title:
///     - error:
///     - requestUri
///     - serviceUrl
///     - payload
public struct PageProperties: Encodable {
    /// The page title of the page to display
    public let title: String

    /// If an error occurred, the `error` property has a descriptive string about the cause of the error.
    /// Check for `nil` on the page.
    ///
    /// Example for Vapor [Leaf](https://docs.vapor.codes/leaf/getting-started/) temples
    /// ~~
    ///  #if(error):
    ///    <div class="error">
    ///      #(error)
    ///    </div>
    ///  #endif
    /// ~~
    public var error: String?

    /// The optional original URL the user called before redirected to the authorisation server
    /// If `nil`, than the login will be for the authorisation server itself.
    public var requestUri: String?

    /// The optional URL of the authorisation server itself to display links to subpages.
    /// If `nil` only relative path's are used.
    public var serviceUrl: String?

    /// The payload of the current users JWT-Token
    /// - SeeAlso:
    ///      - Payload
    public var payload: Payload?

    /// Login mode
    public var mode: LoginMode?

    /// Additional information that is carried around the request
    public var requestInfo: RequestInfo?

    /// The requesting tenant if available
    public var tenant: Tenant?

    public init(
        title: String,
        error: String? = nil,
        requestUri: String? = nil,
        serviceUrl: String? = nil,
        payload: Payload? = nil,
        mode: LoginMode? = nil,
        requestInfo: RequestInfo? = nil,
        tenant: Tenant? = nil
    ) {
        self.title = title
        self.error = error
        self.requestUri = requestUri
        self.serviceUrl = serviceUrl
        self.payload = payload
        self.mode = mode
        self.requestInfo = requestInfo
        self.tenant = tenant
    }
}
