import Foundation

///  The type of requested response code
enum ResponseType: String, Codable {
    ///  indicating that the application expects a `code`  to receive an authorization code if successful.
    case code

}
