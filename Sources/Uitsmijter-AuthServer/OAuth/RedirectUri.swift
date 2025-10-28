import Foundation

/// A protocol defining a type that contains a redirect URI
///
/// Types conforming to this protocol provide a redirect URI that Uitsmijter
/// uses to redirect the authentication response.
protocol RedirectUriProtocol {
    /// The redirect URI where Uitsmijter will send its response.
    ///
    /// This URL represents the destination endpoint that will receive
    /// the authentication result from Uitsmijter.
    var redirect_uri: URL { get }
}

/// Errors that can occur during redirect URI operations.
enum RedirectError: Error {
    /// Indicates that the provided value could not be converted to a valid URL.
    ///
    /// - Parameter value: The value that failed to convert to a URL.
    case notAnUrl(any Sendable)
}

/// A concrete implementation of `RedirectUriProtocol` that encapsulates a redirect URI.
///
/// `RedirectUri` provides a type-safe wrapper around a URL specifically for use
/// as a redirect destination in Uitsmijter authentication flows.
struct RedirectUri: RedirectUriProtocol {
    /// The redirect URI where Uitsmijter will send its response.
    public let redirect_uri: URL

    /// Creates a new redirect URI from a URL instance.
    ///
    /// - Parameter uri: The URL to use as the redirect URI.
    public init(_ uri: URL) {
        redirect_uri = uri
    }

    /// Creates a new redirect URI from a string representation.
    ///
    /// This initializer attempts to parse the provided string as a valid URL.
    /// If the string cannot be converted to a URL, it throws an error.
    ///
    /// - Parameter string: A string representation of the redirect URI.
    /// - Throws: `RedirectError.notAnUrl` if the string cannot be converted to a valid URL.
    public init(_ string: String) throws {
        guard let uri = URL(string: string) else {
            throw RedirectError.notAnUrl(string)
        }
        redirect_uri = uri
    }
}
