import Foundation

/// RSA Public Key in JSON Web Key (JWK) format
///
/// Represents a public RSA key according to RFC 7517 Section 6.3.1.
/// Contains the public key components (modulus and exponent) that can be
/// distributed to clients for JWT signature verification.
///
/// ## Example
///
/// ```json
/// {
///   "kty": "RSA",
///   "use": "sig",
///   "kid": "2024-11-08",
///   "alg": "RS256",
///   "n": "0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78...",
///   "e": "AQAB"
/// }
/// ```
///
/// - SeeAlso: [RFC 7517 Section 6.3.1](https://www.rfc-editor.org/rfc/rfc7517#section-6.3.1)
struct RSAPublicJWK: Codable, Sendable {

    /// Key Type (REQUIRED)
    ///
    /// The "kty" (key type) parameter identifies the cryptographic algorithm
    /// family used with the key. For RSA keys, this MUST be "RSA".
    let kty: String

    /// Public Key Use (OPTIONAL)
    ///
    /// The "use" (public key use) parameter identifies the intended use of
    /// the public key:
    /// - "sig": signature verification
    /// - "enc": encryption
    let use: String?

    /// Key ID (OPTIONAL but RECOMMENDED)
    ///
    /// The "kid" (key ID) parameter is used to match a specific key during
    /// key rollover. This parameter is matched to the "kid" parameter in
    /// the JWT header.
    let kid: String?

    /// Algorithm (OPTIONAL)
    ///
    /// The "alg" (algorithm) parameter identifies the algorithm intended for
    /// use with the key. For RSA signature keys, this is typically "RS256".
    let alg: String?

    /// Modulus (REQUIRED for RSA)
    ///
    /// The "n" (modulus) parameter contains the modulus value for the RSA
    /// public key. It is represented as a Base64urlUInt-encoded value.
    let n: String  // swiftlint:disable:this identifier_name

    /// Exponent (REQUIRED for RSA)
    ///
    /// The "e" (exponent) parameter contains the exponent value for the RSA
    /// public key. It is represented as a Base64urlUInt-encoded value.
    /// Commonly "AQAB" which represents 65537.
    let e: String  // swiftlint:disable:this identifier_name
}

/// JWK Set - Collection of JSON Web Keys
///
/// A JWK Set is a JSON object that represents a set of JWKs. The value of
/// the "keys" parameter is an array of JWK values.
///
/// ## Example
///
/// ```json
/// {
///   "keys": [
///     {
///       "kty": "RSA",
///       "kid": "2024-11-08",
///       "use": "sig",
///       "alg": "RS256",
///       "n": "...",
///       "e": "AQAB"
///     },
///     {
///       "kty": "RSA",
///       "kid": "2024-11-01",
///       "use": "sig",
///       "alg": "RS256",
///       "n": "...",
///       "e": "AQAB"
///     }
///   ]
/// }
/// ```
///
/// - SeeAlso: [RFC 7517 Section 5](https://www.rfc-editor.org/rfc/rfc7517#section-5)
struct JWKSet: Codable, Sendable {

    /// Array of JWK values (REQUIRED)
    ///
    /// The "keys" parameter contains an array of JSON Web Key values.
    /// The array MAY contain multiple keys with different "kid" values
    /// to support key rotation.
    let keys: [RSAPublicJWK]

    /// Create a JWK Set with a single key
    ///
    /// - Parameter key: The JWK to include in the set
    init(key: RSAPublicJWK) {
        self.keys = [key]
    }

    /// Create a JWK Set with multiple keys
    ///
    /// - Parameter keys: Array of JWKs to include in the set
    init(keys: [RSAPublicJWK]) {
        self.keys = keys
    }
}
