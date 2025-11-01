import Foundation
@preconcurrency import JWTKit

/// The secret key used for JWT signing
///
/// Retrieved from the `JWT_SECRET` environment variable. If not set, a random 64-character string is generated.
/// - Warning: In production, always set the `JWT_SECRET` environment variable
///   to ensure consistent token validation across restarts.
fileprivate let jwtSecret = ProcessInfo.processInfo.environment["JWT_SECRET"] ?? String.random(length: 64)

/// Global JWT signer instance using HMAC-SHA256
///
/// This signer is used throughout the application to sign and verify JWT tokens.
/// It uses the HS256 algorithm with the secret key from the environment.
///
/// ## Usage
/// ```swift
/// let token = try jwt_signer.sign(payload)
/// let verifiedPayload = try jwt_signer.verify(tokenString, as: Payload.self)
/// ```
///  ## MARKED Feature rollig secrets
nonisolated(unsafe) let jwt_signer = JWTSigner.hs256(key: jwtSecret)
