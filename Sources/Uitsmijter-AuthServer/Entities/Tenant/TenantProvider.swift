import Foundation

/// Known predefined provider types.
///
/// A predefined provider lets a tenant integrate a well-known external user
/// service without writing the JavaScript by hand — Uitsmijter generates the
/// provider script internally (see ``PredefinedProvider/generatedScript``).
enum ProviderType: String, Codable, Sendable, Equatable {
    /// The Uitrusting multi-tenant user service, v1 (`POST {url}/verify`).
    case uitrustingV1 = "uitrusting/v1"
}

/// A predefined provider definition, e.g. `{ type: "uitrusting/v1", url: "…", token: "…" }`.
struct PredefinedProvider: Codable, Sendable, Equatable {
    /// The kind of external service, which determines how the result is mapped.
    let type: ProviderType

    /// Base URL (or host) of the external service, e.g. `uitrusting.acme.svc`.
    let url: String

    /// Optional shared secret sent to the service as the `X-Internal-Token` header.
    /// When omitted, no authentication header is sent (open mode).
    let token: String?

    /// The JavaScript provider script that implements this predefined provider.
    var generatedScript: String {
        switch type {
        case .uitrustingV1:
            return UitrustingProviderScript.make(url: url, token: token)
        }
    }
}

/// A single entry in a tenant's `providers` list.
///
/// Either a raw JavaScript provider script (the original, still-supported form)
/// or a ``PredefinedProvider`` object that Uitsmijter expands into a script.
///
/// ```yaml
/// providers:
///   - |                         # raw script (unchanged)
///     class UserLoginProvider { … }
///   - type: "uitrusting/v1"     # predefined provider
///     url: uitrusting.acme.svc
///     token: "…"                # optional
/// ```
enum TenantProvider: Codable, Sendable, Equatable, ExpressibleByStringLiteral {
    /// A raw JavaScript provider script.
    case script(String)
    /// A predefined provider expanded to a script by Uitsmijter.
    case predefined(PredefinedProvider)

    /// Allows `providers: ["class …"]` string literals in Swift (tests, defaults).
    init(stringLiteral value: String) {
        self = .script(value)
    }

    /// Decode either a plain string (raw script) or an object (predefined provider).
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self) {
            self = .script(raw)
        } else {
            self = .predefined(try container.decode(PredefinedProvider.self))
        }
    }

    /// Encode back into the same shape it was decoded from.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .script(let raw):
            try container.encode(raw)
        case .predefined(let provider):
            try container.encode(provider)
        }
    }

    /// The effective JavaScript for this entry (raw script, or the generated one).
    var script: String {
        switch self {
        case .script(let raw):
            return raw
        case .predefined(let provider):
            return provider.generatedScript
        }
    }
}
