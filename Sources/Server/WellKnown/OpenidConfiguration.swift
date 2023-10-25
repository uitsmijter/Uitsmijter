import Foundation
import Vapor

struct OpenidConfiguration: Codable {

    /// REQUIRED. URL using the https scheme with no query or fragment component that the OP asserts as its
    /// Issuer Identifier. If Issuer discovery is supported (see Section 2), this value MUST be identical to the issuer
    /// value returned by WebFinger. This also MUST be identical to the iss Claim value in ID Tokens issued from this
    /// Issuer.
    let issuer: String

}
