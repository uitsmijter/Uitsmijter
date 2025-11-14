import _CryptoExtras
import Foundation
import JWTKit

/// RSA Key Pair Generator for JWT signing
///
/// Generates RSA key pairs for asymmetric JWT signing according to RFC 7517.
/// Keys are generated with 2048-bit modulus for security and performance balance.
///
/// ## Usage
///
/// ```swift
/// let generator = KeyGenerator()
/// let keyPair = try await generator.generateKeyPair(kid: "2025-01-08")
/// ```
///
/// ## Key Specifications
///
/// - **Algorithm**: RSA
/// - **Key Size**: 2048 bits (meets RFC 7517 minimum requirements)
/// - **Public Exponent**: 65537 (0x10001, RSA_F4)
/// - **Usage**: JWT signature generation and verification
///
/// ## Thread Safety
///
/// This actor ensures thread-safe key generation operations.
///
/// - SeeAlso: [RFC 7517 Section 6.3](https://www.rfc-editor.org/rfc/rfc7517#section-6.3)
actor KeyGenerator {

    /// Shared singleton instance for key generation
    /// Thread-safe through actor isolation
    static let shared = KeyGenerator()

    /// RSA Key Pair container
    ///
    /// Contains both private and public keys for RSA operations.
    struct RSAKeyPair: Sendable {
        /// Private key PEM for signing JWTs
        let privateKeyPEM: String

        /// Public key PEM for verification
        let publicKeyPEM: String

        /// Key identifier for rotation and matching
        let kid: String

        /// Algorithm identifier
        let algorithm: String = "RS256"
    }

    /// Initialize a new key generator
    init() {}

    /// Generate a new RSA key pair
    ///
    /// Creates a new RSA key pair with the specified key ID using SwiftCrypto.
    /// The key ID is used to match keys during verification and supports key rotation.
    ///
    /// ## Key Rotation
    ///
    /// Generate new keys periodically (e.g., monthly) and include the date in the kid:
    /// ```swift
    /// let formatter = ISO8601DateFormatter()
    /// formatter.formatOptions = [.withFullDate]
    /// let kid = formatter.string(from: Date())
    /// let keyPair = try await generator.generateKeyPair(kid: kid)
    /// ```
    ///
    /// ## Error Handling
    ///
    /// Key generation can fail if:
    /// - The system lacks sufficient entropy
    /// - Invalid key parameters are specified
    /// - Memory allocation fails
    ///
    /// - Parameter kid: Key identifier (recommended format: "YYYY-MM-DD")
    /// - Returns: New RSA key pair with the specified kid
    /// - Throws: KeyGenerationError if key generation fails
    func generateKeyPair(kid: String) async throws -> RSAKeyPair {
        // Generate RSA private key using SwiftCrypto (2048-bit minimum enforced)
        let privateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)

        // Extract public key
        let publicKey = privateKey.publicKey

        // Export to PEM format
        // Use PKCS#8 format for private key (BEGIN PRIVATE KEY) instead of PKCS#1 (BEGIN RSA PRIVATE KEY)
        // PKCS#8 is the modern standard and works better with jwt-kit v5
        let privateKeyPEM = privateKey.pkcs8PEMRepresentation
        // Ensure public key PEM ends with newline (standard PEM format)
        var publicKeyPEM = publicKey.pemRepresentation
        if !publicKeyPEM.hasSuffix("\n") {
            publicKeyPEM += "\n"
        }

        return RSAKeyPair(
            privateKeyPEM: privateKeyPEM,
            publicKeyPEM: publicKeyPEM,
            kid: kid
        )
    }

    /// Convert multiple key pairs to a JWK Set
    ///
    /// This method processes all key pairs without requiring actor isolation,
    /// since it only calls nonisolated methods and doesn't access actor state.
    ///
    /// ## Deadlock Prevention
    ///
    /// By marking this method as nonisolated, we avoid unnecessary actor hops
    /// when called from other actors (like MemoryKeyStorage). This prevents
    /// potential deadlocks that can occur when multiple actors try to acquire
    /// each other's executors.
    ///
    /// Since convertToJWK is nonisolated and this method doesn't access any
    /// actor state, there's no need for actor isolation.
    ///
    /// - Parameter keyPairs: Array of key pairs to convert
    /// - Returns: JWK Set containing all converted public keys
    /// - Throws: ConversionError if any key conversion fails
    nonisolated func convertToJWKSet(_ keyPairs: [RSAKeyPair]) throws -> JWKSet {
        var jwks: [RSAPublicJWK] = []
        for keyPair in keyPairs {
            let jwk = try convertToJWK(keyPair: keyPair)
            jwks.append(jwk)
        }
        return JWKSet(keys: jwks)
    }

    /// Convert public key to JWK format
    ///
    /// Extracts the RSA public key components (modulus and exponent) and encodes
    /// them as Base64url strings according to RFC 7517.
    ///
    /// ## Base64url Encoding
    ///
    /// JWK requires Base64url encoding (not standard Base64):
    /// - Uses `-` and `_` instead of `+` and `/`
    /// - No padding (`=`) characters
    ///
    /// ## Note for Multiple Keys
    ///
    /// If converting multiple key pairs, prefer `convertToJWKSet(_:)` for
    /// convenience and cleaner code.
    ///
    /// - Parameter keyPair: The key pair to extract public key from
    /// - Returns: JWK representation suitable for JWKS endpoint
    /// - Throws: ConversionError if key extraction fails
    /// - Important: This method is nonisolated and synchronous since it doesn't access actor state,
    ///              preventing unnecessary actor suspensions during JWK conversion.
    nonisolated func convertToJWK(keyPair: RSAKeyPair) throws -> RSAPublicJWK {
        // Parse the public key PEM
        let publicKey = try _RSA.Signing.PublicKey(pemRepresentation: keyPair.publicKeyPEM)

        // Extract RSA key components (modulus and exponent)
        let primitives = try publicKey.getKeyPrimitives()

        // Base64url encode (no padding)
        let base64urlN = base64URLEncode(primitives.modulus)
        let base64urlE = base64URLEncode(primitives.publicExponent)

        return RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: keyPair.kid,
            alg: keyPair.algorithm,
            n: base64urlN,
            e: base64urlE
        )
    }

    /// Base64URL encode data according to RFC 4648
    ///
    /// Converts standard base64 to base64url by:
    /// - Replacing `+` with `-`
    /// - Replacing `/` with `_`
    /// - Removing padding `=`
    ///
    /// - Parameter data: Data to encode
    /// - Returns: Base64URL-encoded string
    nonisolated private func base64URLEncode(_ data: Data) -> String {
        var base64 = data.base64EncodedString()

        // Convert to base64url (RFC 4648 Section 5)
        base64 = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return base64
    }

}

/// Key generation errors
enum KeyGenerationError: Error, CustomStringConvertible {
    case insufficientEntropy
    case invalidKeySize
    case generationFailed(String)

    var description: String {
        switch self {
        case .insufficientEntropy:
            return "Insufficient system entropy for key generation"
        case .invalidKeySize:
            return "Invalid RSA key size specified"
        case .generationFailed(let reason):
            return "Key generation failed: \(reason)"
        }
    }
}

/// Key conversion errors
enum ConversionError: Error, CustomStringConvertible {
    case invalidKeyFormat
    case extractionFailed(String)

    var description: String {
        switch self {
        case .invalidKeyFormat:
            return "Invalid key format for JWK conversion"
        case .extractionFailed(let reason):
            return "Key component extraction failed: \(reason)"
        }
    }
}
