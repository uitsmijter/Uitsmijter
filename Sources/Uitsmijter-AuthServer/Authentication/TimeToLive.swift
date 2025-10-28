import Foundation

/// Protocol for types that have a time-to-live (TTL) property.
///
/// Entities conforming to this protocol can specify an expiration time,
/// typically used for session management and caching. The TTL is expressed
/// in seconds from the time of creation or last update.
///
/// ## Usage in Uitsmijter
///
/// TTL is used for:
/// - ``AuthSession``: Authorization code expiration (typically 5-10 minutes)
/// - ``LoginSession``: Login session expiration (typically 2 minutes)
/// - Cache entries: Template and configuration caching
///
/// ## Example
///
/// ```swift
/// struct MySession: TimeToLiveProtocol {
///     var ttl: Int64? = 300  // 5 minutes
/// }
/// ```
///
/// - SeeAlso: ``AuthSession``, ``LoginSession``
protocol TimeToLiveProtocol {
    /// The time-to-live in seconds.
    ///
    /// - `nil`: No expiration (or use system default)
    /// - Positive value: Expiration time in seconds
    var ttl: Int64? { get }
}

/// A concrete implementation of `TimeToLiveProtocol` for decoding TTL values.
///
/// This structure is used when parsing configuration or request parameters
/// that include a TTL specification.
///
/// ## Example
///
/// ```swift
/// let json = """
/// {
///     "ttl": 300
/// }
/// """
/// let ttl = try JSONDecoder().decode(TimeToLive.self, from: json.data(using: .utf8)!)
/// print(ttl.ttl)  // 300
/// ```
struct TimeToLive: TimeToLiveProtocol, Decodable {
    /// The time-to-live in seconds.
    public var ttl: Int64?
}
