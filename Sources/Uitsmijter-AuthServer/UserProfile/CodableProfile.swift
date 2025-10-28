import Foundation

/// A dynamically-typed JSON value container for user profile data.
///
/// `CodableProfile` is a recursive enumeration that can represent any valid JSON structure,
/// allowing backend systems to provide user profile information in flexible formats without
/// requiring predefined schemas. This is particularly useful for authentication providers
/// that return varying profile structures.
///
/// ## Supported Types
///
/// The enum supports all JSON data types:
/// - Primitives: `double`, `integer`, `string`, `boolean`, `null`
/// - Collections: `array` (ordered lists), `object` (key-value dictionaries)
///
/// ## Usage Examples
///
/// ### Creating Profile Data
/// ```swift
/// // Simple string value
/// let name: CodableProfile = .string("Alice")
///
/// // Complex nested object
/// let profile: CodableProfile = .object([
///     "name": .string("Alice"),
///     "age": .integer(30),
///     "email": .string("alice@example.com"),
///     "roles": .array([.string("user"), .string("admin")]),
///     "metadata": .object([
///         "department": .string("Engineering"),
///         "active": .boolean(true)
///     ])
/// ])
/// ```
///
/// ### Accessing Values
/// ```swift
/// // Direct property access with optional chaining
/// let userName = profile.object?["name"]?.string  // Optional("Alice")
/// let userAge = profile.object?["age"]?.int       // Optional(30)
/// let isActive = profile.object?["metadata"]?.object?["active"]?.bool  // Optional(true)
/// ```
///
/// ### Decoding from JSON
/// ```swift
/// let jsonData = """
/// {
///     "username": "alice",
///     "attributes": {
///         "email": "alice@example.com",
///         "verified": true
///     }
/// }
/// """.data(using: .utf8)!
///
/// let profile = try JSONDecoder().decode(CodableProfile.self, from: jsonData)
/// ```
///
/// ## Thread Safety
///
/// `CodableProfile` conforms to `Sendable`, making it safe to use across concurrency domains.
///
/// - Note: This type uses indirect cases for `array` and `object` to support deep nesting
///         without stack overflow issues.
///
/// - SeeAlso: ``UserProfileProtocol`` for the protocol that uses this type
enum CodableProfile: Sendable {
    /// A floating-point number value.
    case double(Double)

    /// An integer number value.
    case integer(Int)

    /// A string text value.
    case string(String)

    /// A boolean true/false value.
    case boolean(Bool)

    /// A null/nil value.
    case null

    /// An ordered array of profile values.
    indirect case array([CodableProfile])

    /// A dictionary/object mapping string keys to profile values.
    indirect case object([String: CodableProfile])
}

/// Encodable conformance for serializing CodableProfile to JSON.
///
/// This extension enables encoding `CodableProfile` values back to JSON format,
/// preserving the original structure and types.
///
/// ## Example
/// ```swift
/// let profile: CodableProfile = .object([
///     "name": .string("Alice"),
///     "age": .integer(30)
/// ])
///
/// let encoder = JSONEncoder()
/// encoder.outputFormatting = .prettyPrinted
/// let jsonData = try encoder.encode(profile)
/// print(String(data: jsonData, encoding: .utf8)!)
/// // Output:
/// // {
/// //   "name": "Alice",
/// //   "age": 30
/// // }
/// ```
extension CodableProfile: Encodable {
    /// Encodes this profile value to the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An encoding error if the value cannot be encoded.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

/// Decodable conformance for parsing JSON into CodableProfile.
///
/// This extension enables automatic decoding of JSON data into the appropriate
/// `CodableProfile` case. The decoder attempts to match the JSON value to each
/// supported type in a specific order to ensure correct type detection.
///
/// ## Decoding Order
///
/// The decoder tries types in this sequence:
/// 1. Integer - Whole numbers without decimal points
/// 2. Double - Numbers with decimal points
/// 3. Boolean - true/false values
/// 4. String - Text values
/// 5. Array - Ordered lists
/// 6. Object - Key-value dictionaries
/// 7. Null - null/nil values
///
/// ## Example
/// ```swift
/// let json = """
/// {
///     "count": 42,
///     "price": 19.99,
///     "available": true,
///     "name": "Product",
///     "tags": ["new", "sale"],
///     "metadata": { "sku": "ABC123" }
/// }
/// """.data(using: .utf8)!
///
/// let profile = try JSONDecoder().decode(CodableProfile.self, from: json)
/// ```
extension CodableProfile: Decodable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer automatically determines the appropriate case based on the
    /// JSON value type encountered during decoding.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError.dataCorrupted` if the value cannot be decoded as any supported type.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try integer first (before double) to preserve whole number precision
        if let value = try? container.decode(Int.self) {
            self = .integer(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        if let value = try? container.decode([CodableProfile].self) {
            self = .array(value)
            return
        }

        if let value = try? container.decode([String: CodableProfile].self) {
            self = .object(value)
            return
        }

        if let container = try? decoder.singleValueContainer(), container.decodeNil() {
            self = .null
            return
        }

        throw DecodingError.dataCorrupted(
            .init(
                codingPath: container.codingPath,
                debugDescription: "Cannot decode profile"
            )
        )
    }
}

/// Convenience properties for accessing typed values from CodableProfile.
///
/// This extension provides safe, optional unwrapping of profile values into their
/// underlying Swift types. All properties return `nil` if the profile value is not
/// of the requested type, enabling safe optional chaining.
///
/// ## Usage Pattern
///
/// These properties are designed for use with optional chaining to navigate nested structures:
///
/// ```swift
/// let profile: CodableProfile = .object([
///     "user": .object([
///         "name": .string("Alice"),
///         "age": .integer(30),
///         "verified": .boolean(true),
///         "score": .double(98.5)
///     ]),
///     "tags": .array([.string("premium"), .string("verified")])
/// ])
///
/// // Safe access with optional chaining
/// let name = profile.object?["user"]?.object?["name"]?.string       // "Alice"
/// let age = profile.object?["user"]?.object?["age"]?.int            // 30
/// let verified = profile.object?["user"]?.object?["verified"]?.bool // true
/// let score = profile.object?["user"]?.object?["score"]?.double     // 98.5
/// let tags = profile.object?["tags"]?.array                         // [.string("premium"), ...]
///
/// // Type mismatch returns nil
/// let wrongType = profile.object?["user"]?.object?["age"]?.string   // nil
/// ```
extension CodableProfile {
    /// Returns the integer value if this profile is an `.integer` case, otherwise `nil`.
    ///
    /// - Returns: The wrapped `Int` value, or `nil` if this is not an integer.
    var int: Int? {
        guard case let .integer(value) = self else {
            return nil
        }
        return value
    }

    /// Returns the double value if this profile is a `.double` case, otherwise `nil`.
    ///
    /// - Returns: The wrapped `Double` value, or `nil` if this is not a double.
    var double: Double? {
        guard case let .double(value) = self else {
            return nil
        }
        return value
    }

    /// Returns the string value if this profile is a `.string` case, otherwise `nil`.
    ///
    /// - Returns: The wrapped `String` value, or `nil` if this is not a string.
    var string: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }

    /// Checks if this profile represents a null value.
    ///
    /// - Returns: `true` if this is the `.null` case, `false` otherwise.
    var isNil: Bool {
        guard case .null = self else {
            return false
        }
        return true
    }

    /// Returns the boolean value if this profile is a `.boolean` case, otherwise `nil`.
    ///
    /// - Returns: The wrapped `Bool` value, or `nil` if this is not a boolean.
    var bool: Bool? {
        guard case let .boolean(value) = self else {
            return nil
        }
        return value
    }

    /// Returns the array value if this profile is an `.array` case, otherwise `nil`.
    ///
    /// - Returns: The wrapped array of `CodableProfile` values, or `nil` if this is not an array.
    ///
    /// ## Example
    /// ```swift
    /// let tags: CodableProfile = .array([.string("admin"), .string("user")])
    /// if let tagsList = tags.array {
    ///     for tag in tagsList {
    ///         print(tag.string ?? "")
    ///     }
    /// }
    /// ```
    var array: [CodableProfile]? {
        guard case let .array(value) = self else {
            return nil
        }
        return value
    }

    /// Returns the object dictionary if this profile is an `.object` case, otherwise `nil`.
    ///
    /// - Returns: The wrapped dictionary mapping string keys to `CodableProfile` values,
    ///           or `nil` if this is not an object.
    ///
    /// ## Example
    /// ```swift
    /// let user: CodableProfile = .object([
    ///     "name": .string("Alice"),
    ///     "role": .string("admin")
    /// ])
    /// if let userObj = user.object {
    ///     let name = userObj["name"]?.string  // "Alice"
    ///     let role = userObj["role"]?.string  // "admin"
    /// }
    /// ```
    var object: [String: CodableProfile]? {
        guard case let .object(value) = self else {
            return nil
        }
        return value
    }
}
