import CJWTKitBoringSSL
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

    /// Key size in bits (2048 is the minimum recommended for RSA)
    private static let keySize: Int32 = 2048

    /// Initialize a new key generator
    init() {}

    /// Generate a new RSA key pair
    ///
    /// Creates a new RSA key pair with the specified key ID using BoringSSL.
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
        // Create RSA structure
        guard let rsa = CJWTKitBoringSSL_RSA_new() else {
            throw KeyGenerationError.generationFailed("Failed to allocate RSA structure")
        }
        defer { CJWTKitBoringSSL_RSA_free(rsa) }

        // Create BIGNUM for exponent (65537 = 0x10001 = RSA_F4)
        guard let exponent = CJWTKitBoringSSL_BN_new() else {
            throw KeyGenerationError.generationFailed("Failed to allocate BIGNUM for exponent")
        }
        defer { CJWTKitBoringSSL_BN_free(exponent) }

        // Set exponent to 65537 (RSA_F4)
        guard CJWTKitBoringSSL_BN_set_word(exponent, 0x10001) == 1 else {
            throw KeyGenerationError.generationFailed("Failed to set exponent value")
        }

        // Generate RSA key pair
        guard CJWTKitBoringSSL_RSA_generate_key_ex(rsa, Self.keySize, exponent, nil) == 1 else {
            throw KeyGenerationError.insufficientEntropy
        }

        // Create EVP_PKEY wrapper for PEM export
        guard let pkey = CJWTKitBoringSSL_EVP_PKEY_new() else {
            throw KeyGenerationError.generationFailed("Failed to allocate EVP_PKEY")
        }
        defer { CJWTKitBoringSSL_EVP_PKEY_free(pkey) }

        // Assign RSA key to EVP_PKEY (RSA_up_ref increments reference count)
        CJWTKitBoringSSL_RSA_up_ref(rsa)
        guard CJWTKitBoringSSL_EVP_PKEY_assign_RSA(pkey, rsa) == 1 else {
            throw KeyGenerationError.generationFailed("Failed to assign RSA to EVP_PKEY")
        }

        // Export private key to PEM
        let privateKeyPEM = try exportPrivateKeyPEM(pkey: pkey)

        // Export public key to PEM
        let publicKeyPEM = try exportPublicKeyPEM(pkey: pkey)

        return RSAKeyPair(
            privateKeyPEM: privateKeyPEM,
            publicKeyPEM: publicKeyPEM,
            kid: kid
        )
    }

    /// Export private key to PEM format
    ///
    /// - Parameter pkey: EVP_PKEY containing the RSA key
    /// - Returns: Private key in PEM format
    /// - Throws: KeyGenerationError if export fails
    private func exportPrivateKeyPEM(pkey: OpaquePointer) throws -> String {
        guard let bio = CJWTKitBoringSSL_BIO_new(CJWTKitBoringSSL_BIO_s_mem()) else {
            throw KeyGenerationError.generationFailed("Failed to create BIO for private key")
        }
        defer { CJWTKitBoringSSL_BIO_free(bio) }

        guard CJWTKitBoringSSL_PEM_write_bio_PrivateKey(bio, pkey, nil, nil, 0, nil, nil) == 1 else {
            throw KeyGenerationError.generationFailed("Failed to write private key to PEM")
        }

        return try readBIOToString(bio: bio)
    }

    /// Export public key to PEM format
    ///
    /// - Parameter pkey: EVP_PKEY containing the RSA key
    /// - Returns: Public key in PEM format
    /// - Throws: KeyGenerationError if export fails
    private func exportPublicKeyPEM(pkey: OpaquePointer) throws -> String {
        guard let bio = CJWTKitBoringSSL_BIO_new(CJWTKitBoringSSL_BIO_s_mem()) else {
            throw KeyGenerationError.generationFailed("Failed to create BIO for public key")
        }
        defer { CJWTKitBoringSSL_BIO_free(bio) }

        guard CJWTKitBoringSSL_PEM_write_bio_PUBKEY(bio, pkey) == 1 else {
            throw KeyGenerationError.generationFailed("Failed to write public key to PEM")
        }

        return try readBIOToString(bio: bio)
    }

    /// Read BIO contents to String
    ///
    /// - Parameter bio: BIO containing PEM data
    /// - Returns: PEM string
    /// - Throws: KeyGenerationError if reading fails
    private func readBIOToString(bio: UnsafeMutablePointer<BIO>) throws -> String {
        var pointer: UnsafeMutablePointer<CChar>?
        let length = CJWTKitBoringSSL_BIO_get_mem_data(bio, &pointer)

        guard length > 0, let pemPointer = pointer else {
            throw KeyGenerationError.generationFailed("Failed to read PEM data from BIO")
        }

        let data = Data(bytes: pemPointer, count: Int(length))
        guard let pemString = String(data: data, encoding: .utf8) else {
            throw KeyGenerationError.generationFailed("Failed to decode PEM data as UTF-8")
        }

        return pemString
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
    /// - Parameter keyPair: The key pair to extract public key from
    /// - Returns: JWK representation suitable for JWKS endpoint
    /// - Throws: ConversionError if key extraction fails
    func convertToJWK(keyPair: RSAKeyPair) async throws -> RSAPublicJWK {
        // Parse the public key PEM to extract components
        guard let pkey = try loadPublicKeyPEM(pem: keyPair.publicKeyPEM) else {
            throw ConversionError.extractionFailed("Failed to load public key PEM")
        }
        defer { CJWTKitBoringSSL_EVP_PKEY_free(pkey) }

        // Extract RSA from EVP_PKEY
        guard let rsa = CJWTKitBoringSSL_EVP_PKEY_get0_RSA(pkey) else {
            throw ConversionError.extractionFailed("Failed to extract RSA from EVP_PKEY")
        }

        // Get modulus (n)
        guard let modulusPtr = CJWTKitBoringSSL_RSA_get0_n(rsa) else {
            throw ConversionError.extractionFailed("Failed to get modulus")
        }

        // Get exponent (e)
        guard let exponentPtr = CJWTKitBoringSSL_RSA_get0_e(rsa) else {
            throw ConversionError.extractionFailed("Failed to get exponent")
        }

        // Convert modulus to bytes
        let modulusSize = CJWTKitBoringSSL_BN_num_bytes(modulusPtr)
        var modulusBytes = [UInt8](repeating: 0, count: Int(modulusSize))
        CJWTKitBoringSSL_BN_bn2bin(modulusPtr, &modulusBytes)

        // Convert exponent to bytes
        let exponentSize = CJWTKitBoringSSL_BN_num_bytes(exponentPtr)
        var exponentBytes = [UInt8](repeating: 0, count: Int(exponentSize))
        CJWTKitBoringSSL_BN_bn2bin(exponentPtr, &exponentBytes)

        // Base64url encode (no padding)
        let base64urlN = base64URLEncode(Data(modulusBytes))
        let base64urlE = base64URLEncode(Data(exponentBytes))

        return RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: keyPair.kid,
            alg: keyPair.algorithm,
            n: base64urlN,
            e: base64urlE
        )
    }

    /// Load public key PEM
    ///
    /// - Parameter pem: PEM-encoded public key
    /// - Returns: EVP_PKEY pointer (caller must free)
    /// - Throws: ConversionError if loading fails
    private func loadPublicKeyPEM(pem: String) throws -> OpaquePointer? {
        let pemData = [UInt8](pem.utf8)
        return try pemData.withUnsafeBytes { buffer in
            guard let bio = CJWTKitBoringSSL_BIO_new_mem_buf(buffer.baseAddress, buffer.count) else {
                throw ConversionError.extractionFailed("Failed to create BIO from PEM")
            }
            defer { CJWTKitBoringSSL_BIO_free(bio) }

            guard let pkey = CJWTKitBoringSSL_PEM_read_bio_PUBKEY(bio, nil, nil, nil) else {
                throw ConversionError.extractionFailed("Failed to read public key from PEM")
            }

            return pkey
        }
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
    private func base64URLEncode(_ data: Data) -> String {
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
