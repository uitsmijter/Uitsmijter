import Foundation
import Vapor

protocol LoginIdProtocol: Content {
    var loginid: UUID { get }
}

struct LoginId: LoginIdProtocol {
    let loginid: UUID
}
