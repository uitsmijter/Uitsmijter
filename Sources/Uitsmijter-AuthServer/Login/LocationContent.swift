import Foundation

// MARK: - Location Content

/// Represents a location URL extracted from request content.
///
/// This structure is used to parse and validate location parameters from
/// login forms and OAuth requests. It provides convenient URL parsing.
///
/// ## Usage
///
/// ```swift
/// let content = try request.content.decode(LocationContent.self)
/// if let url = content.url {
///     // Process the location URL
/// }
/// ```
///
/// ## Topics
///
/// ### Properties
/// - ``location``
/// - ``url``
///
/// ### Initialization
/// - ``init(location:)``
///
/// - SeeAlso: ``LoginForm``
/// - SeeAlso: ``RequestClientMiddleware``
struct LocationContent: Codable, Sendable {
    /// The raw location string.
    public let location: String

    /// The parsed URL representation of the location.
    ///
    /// Returns `nil` if the location string is not a valid URL.
    public var url: URL? {
        URL(string: location)
    }

    /// Creates a new location content instance.
    ///
    /// - Parameter location: The location URL string
    public init(location: String) {
        self.location = location
    }
}
