import Foundation

/// Protocol defining the essential user profile information for authentication and authorization.
///
/// `UserProfileProtocol` establishes the contract for user identity and authorization data
/// used throughout the Uitsmijter authorization system. Implementations of this protocol
/// are included in JWT tokens and used for access control decisions.
///
/// ## Purpose
///
/// This protocol serves as the foundation for:
/// - User authentication and identity verification
/// - Role-based access control (RBAC)
/// - Custom user attribute storage
/// - JWT token payload construction
///
/// ## Implementation Requirements
///
/// Conforming types must provide:
/// - A `role` for authorization decisions
/// - A `user` identifier (username, email, or ID)
/// - Optional `profile` data for additional attributes
///
/// ## Usage in Authentication Flow
///
/// ```swift
/// // After successful authentication, create a user profile
/// let userProfile = UserProfile(
///     role: "admin",
///     user: "alice@example.com",
///     profile: .object([
///         "department": .string("Engineering"),
///         "permissions": .array([.string("read"), .string("write")])
///     ])
/// )
///
/// // Profile is embedded in JWT tokens for subsequent requests
/// let token = try generateJWT(for: userProfile)
/// ```
///
/// - SeeAlso: ``UserProfile`` for the default implementation
/// - SeeAlso: ``CodableProfile`` for the flexible profile data structure
protocol UserProfileProtocol {
    /// The user's role within the authorization system.
    ///
    /// This property determines the user's permissions and access levels throughout the system.
    /// Roles are used for authorization decisions, access control policies, and permission checks.
    ///
    /// ## Common Roles
    ///
    /// Typical role values include:
    /// - `"admin"` - Full system access
    /// - `"user"` - Standard user access
    /// - `"guest"` - Limited read-only access
    /// - Custom role names as defined by your authorization policy
    ///
    /// ## Example
    /// ```swift
    /// let profile = UserProfile(role: "admin", user: "alice@example.com")
    /// if profile.role == "admin" {
    ///     // Grant administrative access
    /// }
    /// ```
    var role: String { get set }

    /// The unique identifier or username of the user.
    ///
    /// This property contains the primary user identifier used for authentication and identity.
    /// The value is typically an email address, username, or unique user ID from the backend
    /// authentication system.
    ///
    /// ## Format
    ///
    /// Common formats include:
    /// - Email address: `"user@example.com"`
    /// - Username: `"johndoe"`
    /// - UUID: `"550e8400-e29b-41d4-a716-446655440000"`
    /// - Custom identifier from your authentication provider
    ///
    /// ## Example
    /// ```swift
    /// let profile = UserProfile(role: "user", user: "alice@example.com")
    /// print("Authenticated user: \(profile.user)")
    /// ```
    var user: String { get set }
    
    // The users allowed scopes
    var scope: String { get set }

    /// Additional custom user profile data in a flexible JSON-like structure.
    ///
    /// This optional property allows storing arbitrary user attributes beyond the core
    /// `role` and `user` fields. The flexible ``CodableProfile`` type can represent any
    /// valid JSON structure, making it ideal for provider-specific user data that varies
    /// across different authentication backends.
    ///
    /// ## Use Cases
    ///
    /// - Store provider-specific attributes (email verification status, avatar URL, etc.)
    /// - Include custom user metadata (department, location, preferences)
    /// - Embed nested authorization data (permissions, group memberships)
    /// - Preserve additional fields from SSO providers
    ///
    /// ## Example
    /// ```swift
    /// let profile = UserProfile(
    ///     role: "user",
    ///     user: "alice@example.com",
    ///     profile: .object([
    ///         "email_verified": .boolean(true),
    ///         "avatar_url": .string("https://example.com/avatars/alice.jpg"),
    ///         "department": .string("Engineering"),
    ///         "permissions": .array([
    ///             .string("read:documents"),
    ///             .string("write:documents")
    ///         ])
    ///     ])
    /// )
    ///
    /// // Access nested profile data
    /// let isVerified = profile.profile?.object?["email_verified"]?.bool  // true
    /// let dept = profile.profile?.object?["department"]?.string          // "Engineering"
    /// ```
    ///
    /// - Note: This field is read-only in the protocol but may be mutable in implementations.
    var profile: CodableProfile? { get }
}

/// Default implementation of user profile information.
///
/// `UserProfile` is a concrete implementation of ``UserProfileProtocol`` that provides
/// a simple, value-type container for user authentication and authorization data. This
/// struct is the standard type used throughout Uitsmijter for representing authenticated
/// users.
///
/// ## Features
///
/// - **Value Semantics**: As a struct, `UserProfile` is copied on assignment, ensuring thread safety
/// - **Codable**: Can be encoded/decoded for storage or transmission (when implemented)
/// - **Flexible Profile Data**: Supports arbitrary JSON-like user attributes via ``CodableProfile``
///
/// ## Usage in Authentication
///
/// ```swift
/// // Basic user profile
/// let basicProfile = UserProfile(
///     role: "user",
///     user: "alice@example.com"
/// )
///
/// // Profile with additional data
/// let detailedProfile = UserProfile(
///     role: "admin",
///     user: "bob@example.com",
///     profile: .object([
///         "name": .string("Bob Smith"),
///         "department": .string("IT"),
///         "employee_id": .integer(12345),
///         "is_manager": .boolean(true),
///         "direct_reports": .array([
///             .string("alice@example.com"),
///             .string("charlie@example.com")
///         ])
///     ])
/// )
/// ```
///
/// ## Modifying Profile Data
///
/// ```swift
/// var profile = UserProfile(role: "user", user: "alice@example.com")
///
/// // Update role after promotion
/// profile.role = "admin"
///
/// // Add profile data
/// profile.profile = .object([
///     "promoted_date": .string("2025-01-15"),
///     "previous_role": .string("user")
/// ])
/// ```
///
/// - SeeAlso: ``UserProfileProtocol`` for the protocol definition
/// - SeeAlso: ``CodableProfile`` for the profile data structure
struct UserProfile: UserProfileProtocol {
    
    /// The user's role for authorization decisions.
    ///
    /// This property determines access levels and permissions throughout the system.
    ///
    /// - SeeAlso: ``UserProfileProtocol/role`` for detailed role usage documentation
    var role: String

    /// The unique identifier or username of the user.
    ///
    /// This is the primary user identifier used for authentication and identity.
    ///
    /// - SeeAlso: ``UserProfileProtocol/user`` for identifier format documentation
    var user: String

    var scope: String
    /// Optional additional profile data with flexible structure.
    ///
    /// Stores custom user attributes in a JSON-like format.
    ///
    /// - SeeAlso: ``UserProfileProtocol/profile`` for usage examples and common patterns
    var profile: CodableProfile?

    /// Creates a new user profile with the specified authentication and authorization data.
    ///
    /// - Parameters:
    ///   - role: The user's role for authorization (e.g., "admin", "user", "guest").
    ///   - user: The username, email, or unique identifier of the user.
    ///   - profile: Optional additional profile data containing custom user attributes.
    ///              Defaults to `nil` if not provided.
    ///
    /// ## Example
    /// ```swift
    /// // Minimal profile
    /// let simple = UserProfile(role: "user", user: "alice@example.com")
    ///
    /// // Profile with custom data
    /// let detailed = UserProfile(
    ///     role: "admin",
    ///     user: "bob@example.com",
    ///     profile: .object([
    ///         "department": .string("Engineering"),
    ///         "level": .integer(5)
    ///     ])
    /// )
    /// ```
    init(role: String, user: String, scope: String? = nil, profile: CodableProfile? = nil) {
        self.role = role
        self.user = user
        self.scope = scope ?? ""
        self.profile = profile
    }
}
