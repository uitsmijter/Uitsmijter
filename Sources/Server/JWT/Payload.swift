import Foundation
import JWT

/// JWT payload structure the authorisation server singes for a succeeded authorisation request
struct Payload: JWTPayload, SubjectProtocol, UserProfileProtocol {

    /// Maps the longer Swift property names to the
    /// shortened keys used in the JWT payload.
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case tenant = "tenant"
        case responsibility = "responsibility"
        case role = "role"
        case user = "user"
        case profile = "profile"
    }

    /// The "sub" (subject) claim identifies the principal that is the
    /// subject of the JWT.
    var subject: SubjectClaim

    /// The "exp" (expiration time) claim identifies the expiration time on
    /// or after which the JWT MUST NOT be accepted for processing.
    var expiration: ExpirationClaim

    // MARK: - Custom data.

    /// The tenant for witch the payload is valid
    var tenant: String

    /// A hash for the responsibility check
    var responsibility: String?

    /// The users role.
    var role: String

    /// username of the user
    var user: String

    /// Untyped profile
    var profile: CodableProfile?

    // MARK: - JWTPayload

    /// Function to verify if the token is not expired
    ///
    /// - Parameter signer: JWTSigner to verify the token
    /// - Throws: JWTError
    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}
