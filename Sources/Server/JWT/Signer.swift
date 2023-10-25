import Foundation
import JWTKit

fileprivate let jwtSecret = ProcessInfo.processInfo.environment["JWT_SECRET"] ?? String.random(length: 64)
let jwt_signer = JWTSigner.hs256(key: jwtSecret)
