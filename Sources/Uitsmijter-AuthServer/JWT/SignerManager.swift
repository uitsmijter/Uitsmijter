import Foundation
import JWTKit

/// Manages JWT signing with support for both HS256 (legacy) and RS256 (RSA) algorithms.
///
/// The SignerManager provides a unified interface for JWT signing that supports:
/// - **HS256**: Symmetric HMAC signing (legacy, for backwards compatibility)
/// - **RS256**: Asymmetric RSA signing (new, recommended)
///
/// ## Algorithm Selection
///
/// The signing algorithm is controlled by the `JWT_ALGORITHM` environment variable:
/// - `HS256`: Use symmetric HMAC signing (default for backwards compatibility)
/// - `RS256`: Use asymmetric RSA signing with automatic key rotation
///
/// ## RSA Key Management
///
/// When using RS256, the manager integrates with ``KeyStorage`` to:
/// - Automatically generate RSA keys on first use
/// - Support key rotation
/// - Include the `kid` (key ID) in JWT headers
/// - Expose public keys via JWKS endpoint
///
/// ## Migration from HS256 to RS256
///
/// To migrate existing deployments:
/// 1. Keep `JWT_ALGORITHM=HS256` initially (default)
/// 2. Deploy code with RS256 support
/// 3. Change to `JWT_ALGORITHM=RS256`
/// 4. Old HS256 tokens remain valid until expiration
/// 5. New tokens use RS256 with kid headers
///
/// ## Usage
///
/// ```swift
/// let manager = SignerManager.shared
///
/// // Sign a payload (algorithm determined by environment)
/// let (tokenString, kid) = try await manager.sign(payload)
///
/// // Verify a token (automatically detects algorithm)
/// let payload = try await manager.verify(tokenString, as: Payload.self)
/// ```
///
/// ## Thread Safety
///
/// This actor ensures thread-safe access to signers and keys across concurrent requests.
///
/// - SeeAlso: ``KeyStorage``
/// - SeeAlso: ``Token``
actor SignerManager {

    /// Shared singleton instance
    static let shared = SignerManager()

    /// Supported JWT algorithms
    enum Algorithm: String {
        case hs256 = "HS256"
        case rs256 = "RS256"
    }

    /// HS256 signer (always initialized for backward compatibility and verification)
    private let hs256Signer: JWTSigner

    /// Key storage for RSA keys
    /// - Note: When nil, dynamically accesses KeyStorage.shared
    private let keyStorage: KeyStorage?

    /// Initialize the signer manager with optional KeyStorage
    ///
    /// - Parameter keyStorage: Optional KeyStorage instance. If nil, uses KeyStorage.shared dynamically.
    ///   This parameter enables dependency injection for testing while maintaining the singleton pattern for production.
    init(keyStorage: KeyStorage? = nil) {
        self.keyStorage = keyStorage

        // Always initialize HS256 signer (for verification and legacy support)
        self.hs256Signer = JWTSigner.hs256(key: jwtSecret)
    }

    /// Sign a payload with the specified algorithm
    ///
    /// Creates a signed JWT token using either HS256 or RS256 based on the
    /// provided algorithm parameter.
    ///
    /// ## HS256 Signing
    ///
    /// - No kid is included in the header
    /// - Returns nil for the kid value
    ///
    /// ## RS256 Signing
    ///
    /// - Includes kid in the JWT header
    /// - Returns the kid of the signing key
    /// - Automatically generates a key if none exists
    ///
    /// - Parameters:
    ///   - payload: The JWT payload to sign
    ///   - algorithm: The algorithm to use (HS256 or RS256)
    /// - Returns: Tuple of (signed JWT string, optional kid)
    /// - Throws: JWTError if signing fails
    func sign<Payload: JWTPayload>(
        _ payload: Payload,
        algorithm: Algorithm
    ) async throws -> (token: String, kid: String?) {
        switch algorithm {
        case .hs256:
            // Sign with HS256 (no kid)
            let signers = JWTSigners()
            signers.use(hs256Signer)
            let token = try signers.sign(payload)
            return (token, nil)

        case .rs256:
            // Get KeyStorage (dynamically access shared if not injected)
            let storage = keyStorage ?? KeyStorage.shared

            // Get the active RSA key PEM
            let activeKeyPEM = try await storage.getActiveSigningKeyPEM()

            // Get the active key metadata to retrieve kid
            let activeKeyPair = try await storage.getActiveKey()
            let kid = activeKeyPair.kid

            // Create RSA signer from PEM
            let rsaKey = try RSAKey.private(pem: activeKeyPEM)
            let rsaSigner = JWTSigner.rs256(key: rsaKey)

            // Sign with RS256 (include kid)
            let signers = JWTSigners()
            signers.use(rsaSigner, kid: JWKIdentifier(string: kid), isDefault: true)
            let token = try signers.sign(payload, kid: JWKIdentifier(string: kid))
            return (token, kid)
        }
    }

    /// Sign a payload with default algorithm from environment
    ///
    /// Convenience method that uses the JWT_ALGORITHM environment variable to determine
    /// the signing algorithm. Falls back to HS256 if not set.
    ///
    /// - Parameter payload: The JWT payload to sign
    /// - Returns: Tuple of (signed JWT string, optional kid)
    /// - Throws: JWTError if signing fails
    func sign<Payload: JWTPayload>(
        _ payload: Payload
    ) async throws -> (token: String, kid: String?) {
        let algorithmString = ProcessInfo.processInfo.environment["JWT_ALGORITHM"] ?? "HS256"
        let algorithm = Algorithm(rawValue: algorithmString.uppercased()) ?? .hs256
        return try await sign(payload, algorithm: algorithm)
    }

    /// Sign a payload with algorithm specified as string
    ///
    /// Convenience method that accepts algorithm as a string (e.g., "HS256" or "RS256")
    /// and delegates to the main sign method.
    ///
    /// - Parameters:
    ///   - payload: The JWT payload to sign
    ///   - algorithmString: "HS256" or "RS256"
    /// - Returns: Tuple of (signed JWT string, optional kid)
    /// - Throws: SignerError if algorithm is invalid, JWTError if signing fails
    func sign<Payload: JWTPayload>(
        _ payload: Payload,
        algorithmString: String
    ) async throws -> (token: String, kid: String?) {
        guard let algorithm = Algorithm(rawValue: algorithmString.uppercased()) else {
            throw SignerError.algorithmNotSupported(algorithmString)
        }
        return try await sign(payload, algorithm: algorithm)
    }

    /// Verify a JWT token and extract its payload
    ///
    /// Verifies the token signature and decodes the payload. The manager
    /// registers all possible signers (HS256 and available RSA keys) and
    /// lets JWTKit automatically select the correct one based on the JWT header.
    ///
    /// ## Algorithm Detection
    ///
    /// - JWTKit reads the `alg` field from the JWT header
    /// - For HS256: Uses the configured HS256 signer
    /// - For RS256: Uses the `kid` from header to select the correct public key
    ///
    /// ## Key Rotation Support
    ///
    /// For RS256 tokens, the `kid` header is used to select the correct verification key.
    /// This allows seamless key rotation without invalidating existing tokens.
    ///
    /// - Parameters:
    ///   - token: The JWT token string to verify
    ///   - payloadType: The expected payload type
    /// - Returns: The decoded payload
    /// - Throws: JWTError if verification fails
    func verify<Payload: JWTPayload>(_ token: String, as payloadType: Payload.Type) async throws -> Payload {
        let signers = JWTSigners()

        // Add HS256 signer (always available for verification)
        signers.use(hs256Signer)

        // Get KeyStorage (dynamically access shared if not injected)
        let storage = keyStorage ?? KeyStorage.shared

        // Add all RSA public keys from storage
        let allKeys = await storage.getAllKeys()
        for keyPair in allKeys {
            do {
                let rsaKey = try RSAKey.public(pem: keyPair.publicKeyPEM)
                let rsaSigner = JWTSigner.rs256(key: rsaKey)
                signers.use(rsaSigner, kid: JWKIdentifier(string: keyPair.kid))
            } catch {
                // Skip keys that fail to load
                continue
            }
        }

        // JWTKit will automatically select the correct signer based on alg and kid
        return try signers.verify(token, as: payloadType)
    }

}

/// Signer errors
enum SignerError: Error, CustomStringConvertible {
    case signerNotInitialized
    case algorithmNotSupported(String)

    var description: String {
        switch self {
        case .signerNotInitialized:
            return "JWT signer not initialized"
        case .algorithmNotSupported(let alg):
            return "JWT algorithm not supported: \(alg)"
        }
    }
}
