import Foundation
import Vapor
import Logger

/// Maps Uitsmijter service domains to their configured cookie domains.
///
/// In multi-domain deployments, the Uitsmijter login page may run on a host like
/// `login.ops.example.com` while cookies should be set on a broader domain like
/// `.ops.example.com` so that all subdomains can read them.
///
/// The mapping is loaded from the `COOKIE_DOMAINS` environment variable, which is
/// expected to contain a JSON object mapping service domains to cookie domains:
///
/// ```json
/// {"login.ops.example.com":".ops.example.com","login.example.com":".example.com"}
/// ```
///
/// This is populated by the Helm chart from `values.domains[].cookieDomain`.
///
/// - SeeAlso: ``resolve(for:)``
struct CookieDomainMapping {

    /// The domain → cookieDomain mapping loaded at startup.
    private static let mapping: [String: String] = {
        guard let raw = Environment.get("COOKIE_DOMAINS") else {
            return [:]
        }
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            Log.warning("COOKIE_DOMAINS is set but not valid JSON: \(raw)")
            return [:]
        }
        Log.info("Loaded cookie domain mapping: \(dict)")
        return dict
    }()

    /// Resolves the cookie domain for a given host.
    ///
    /// If a mapping exists for the host, returns the configured cookie domain.
    /// Otherwise returns the host unchanged.
    ///
    /// - Parameter host: The service host (e.g. `login.ops.example.com`)
    /// - Returns: The cookie domain (e.g. `.ops.example.com`) or the host itself
    static func resolve(for host: String) -> String {
        mapping[host] ?? host
    }
}
