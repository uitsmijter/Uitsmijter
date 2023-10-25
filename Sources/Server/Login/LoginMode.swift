import Foundation
import Vapor

enum LoginMode: String, Codable {
    case interceptor
    case oauth
}
