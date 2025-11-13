import Foundation
@preconcurrency import JWTKit

/// The secret key used for JWT signing
///
/// Retrieved from the `JWT_SECRET` environment variable. If not set, a random 64-character string is generated.
/// This secret is shared throughout the application to ensure consistency.
/// - Warning: In production, always set the `JWT_SECRET` environment variable
///   to ensure consistent token validation across restarts.
let jwtSecret = ProcessInfo.processInfo.environment["JWT_SECRET"] ?? String.random(length: 64)

// Note: jwt-kit v5 removed JWTSigner as a standalone type.
// Use SignerManager.shared instead for JWT operations.
//
// Migration note: The global jwt_signer has been removed in favor of
// SignerManager which provides better support for key rotation and
// multiple algorithms (HS256 and RS256).
