import Foundation
@preconcurrency import JWT

/// Protocol defining the subject claim for JWT tokens.
///
/// The subject claim ("sub") is a standard JWT claim that identifies the principal
/// (typically a user) that is the subject of the token. In Uitsmijter, this is used
/// to uniquely identify authenticated users across different tenants.
///
/// ## JWT Standard
///
/// According to RFC 7519, the "sub" claim:
/// - Is case-sensitive
/// - Must be unique within the issuer's domain
/// - Scoped to be locally unique in the context of the issuer
///
/// - SeeAlso: [RFC 7519 Section 4.1.2](https://tools.ietf.org/html/rfc7519#section-4.1.2)
protocol SubjectProtocol: Sendable {

    /// The "sub" (subject) claim identifies the principal that is the subject of the JWT.
    ///
    /// This claim uniquely identifies the authenticated user or entity. Common values include:
    /// - User IDs (e.g., "user-12345")
    /// - Email addresses (e.g., "user@example.com")
    /// - Unique usernames
    ///
    /// The value should remain stable for the user across authentication sessions.
    var subject: SubjectClaim { get set }
}

/// Concrete implementation of the subject claim.
///
/// This struct provides a basic implementation of ``SubjectProtocol`` that can be
/// used when decoding subject information from JSON or other data sources.
///
/// ## Usage
///
/// ```swift
/// let subject = Subject(subject: "user@example.com")
/// let token = try Token(tenantName: "acme", subject: subject.subject, userProfile: profile)
/// ```
struct Subject: SubjectProtocol, Decodable {
    /// The subject claim value.
    var subject: SubjectClaim
}

extension SubjectProtocol {

    /// Decodes subject claims from an array of string values.
    ///
    /// This method processes an array of strings and extracts any valid subject claims
    /// encoded as JSON objects with the format `{"subject": "value"}`. This is useful
    /// when subject information is returned from JavaScript providers or external systems
    /// as serialized JSON strings.
    ///
    /// ## Decoding Process
    ///
    /// For each string in the array:
    /// 1. Attempts to parse it as JSON
    /// 2. If it contains a `subject` field, decodes it as a `Subject`
    /// 3. Valid subjects are collected and returned
    /// 4. Invalid or non-subject strings are silently ignored
    ///
    /// ## Example
    ///
    /// ```swift
    /// let values = [
    ///     "{\"subject\":\"user@example.com\"}",
    ///     "{\"subject\":\"admin@example.com\"}",
    ///     "not a subject"  // This will be ignored
    /// ]
    /// let subjects = SubjectProtocol.decode(from: values)
    /// // Returns array with 2 Subject instances
    /// ```
    ///
    /// ## Use Case
    ///
    /// This is typically used when JavaScript providers return user information that includes
    /// subject claims mixed with other data. The method filters and extracts only valid subjects.
    ///
    /// - Parameter values: Optional array of strings that may contain JSON-encoded subject claims.
    /// - Returns: An array of decoded `SubjectProtocol` instances. Returns empty array if input is `nil`.
    static func decode(from values: [String]?) -> [SubjectProtocol] {
        // is subject given in fetchedValue
        let subjects: [SubjectProtocol]? = values?.compactMap { (element: String?) -> SubjectProtocol? in
            if let element, let data = element.data(using: .utf8) {
                if let result = try? JSONDecoder.main.decode(Subject.self, from: data) {
                    return result
                }
            }
            return nil
        }
        return subjects ?? []
    }
}
