import Foundation

protocol UserProfileProtocol {
    /// The users role.
    var role: String { get set }

    /// username of the user
    var user: String { get set }

    /// Untyped profile
    var profile: CodableProfile? { get }
}

struct UserProfile: UserProfileProtocol {

    var role: String

    var user: String

    var profile: CodableProfile?
}
