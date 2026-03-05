import Foundation

// MARK: - Supporting Types

/// Status of a device authorization flow (RFC 8628)
enum DeviceGrantStatus: String, Codable, Sendable {
    case pending, authorized, denied
}

/// Discriminator for ``AuthSession`` cases and storage key prefix.
enum AuthSessionType: String, Sendable, Equatable {
    case code, refresh, device
}

// MARK: - Per-type session structs

/// Session for the standard OAuth 2.0 authorization code flow.
struct CodeSession: Codable, Sendable {
    let state: String
    let code: Code
    let scopes: [String]
    let payload: Payload?
    let redirect: String
    var ttl: Int64?
    var generated: Date

    init(
        state: String,
        code: Code,
        scopes: [String],
        payload: Payload?,
        redirect: String,
        ttl: Int64? = nil,
        generated: Date = Date()
    ) {
        self.state = state
        self.code = code
        self.scopes = scopes
        self.payload = payload
        self.redirect = redirect
        self.ttl = ttl
        self.generated = generated
    }
}

/// Session for the OAuth 2.0 refresh token flow.
struct RefreshSession: Codable, Sendable {
    let state: String
    let code: Code
    let scopes: [String]
    let payload: Payload?
    let redirect: String
    var ttl: Int64?
    var generated: Date

    init(
        state: String,
        code: Code,
        scopes: [String],
        payload: Payload?,
        redirect: String,
        ttl: Int64? = nil,
        generated: Date = Date()
    ) {
        self.state = state
        self.code = code
        self.scopes = scopes
        self.payload = payload
        self.redirect = redirect
        self.ttl = ttl
        self.generated = generated
    }
}

/// Session for the OAuth 2.0 Device Authorization Grant (RFC 8628).
struct DeviceSession: Codable, Sendable {
    let clientId: String
    let deviceCode: Code
    let userCode: String
    let scopes: [String]
    var payload: Payload?
    var status: DeviceGrantStatus
    var lastPolledAt: Date?
    var ttl: Int64?
    var generated: Date

    init(
        clientId: String,
        deviceCode: Code,
        userCode: String,
        scopes: [String],
        payload: Payload? = nil,
        status: DeviceGrantStatus = .pending,
        lastPolledAt: Date? = nil,
        ttl: Int64? = nil,
        generated: Date = Date()
    ) {
        self.clientId = clientId
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.scopes = scopes
        self.payload = payload
        self.status = status
        self.lastPolledAt = lastPolledAt
        self.ttl = ttl
        self.generated = generated
    }
}

// MARK: - Discriminated Union

/// Session state for OAuth2 authorization flows.
///
/// `AuthSession` is a discriminated union covering the standard authorization code flow,
/// refresh token flow, and the Device Authorization Grant (RFC 8628). The union is stored
/// and retrieved by ``AuthCodeStorageProtocol`` implementations.
///
/// ## Backward Compatibility
///
/// The JSON encoding uses `"type": "code"` / `"type": "refresh"` / `"type": "device"` as
/// the discriminator. Existing Redis sessions encoded with the old flat-struct format decode
/// correctly because they already carry `"type": "code"` or `"type": "refresh"`.
///
/// - SeeAlso: ``CodeSession``, ``RefreshSession``, ``DeviceSession``
enum AuthSession: Codable, TimeToLiveProtocol, Sendable {
    case code(CodeSession)
    case refresh(RefreshSession)
    case device(DeviceSession)

    // MARK: - Forwarding computed properties

    /// The session type discriminator.
    var sessionType: AuthSessionType {
        switch self {
        case .code:    return .code
        case .refresh: return .refresh
        case .device:  return .device
        }
    }

    /// The primary storage lookup key value.
    var codeValue: String {
        switch self {
        case .code(let sess):    return sess.code.value
        case .refresh(let sess): return sess.code.value
        case .device(let sess):  return sess.deviceCode.value
        }
    }

    /// The authenticated user's payload, or `nil` for pending device sessions.
    var payload: Payload? {
        switch self {
        case .code(let sess):    return sess.payload
        case .refresh(let sess): return sess.payload
        case .device(let sess):  return sess.payload
        }
    }

    /// The OAuth2 scopes approved for this session.
    var scopes: [String] {
        switch self {
        case .code(let sess):    return sess.scopes
        case .refresh(let sess): return sess.scopes
        case .device(let sess):  return sess.scopes
        }
    }

    /// The CSRF state parameter (empty for device sessions, which have no redirect).
    var state: String {
        switch self {
        case .code(let sess):    return sess.state
        case .refresh(let sess): return sess.state
        case .device:            return ""
        }
    }

    /// The redirect URI (empty for device sessions, which have no redirect).
    var redirect: String {
        switch self {
        case .code(let sess):    return sess.redirect
        case .refresh(let sess): return sess.redirect
        case .device:            return ""
        }
    }

    // MARK: - TimeToLiveProtocol

    var ttl: Int64? {
        switch self {
        case .code(let sess):    return sess.ttl
        case .refresh(let sess): return sess.ttl
        case .device(let sess):  return sess.ttl
        }
    }

    var generated: Date {
        switch self {
        case .code(let sess):    return sess.generated
        case .refresh(let sess): return sess.generated
        case .device(let sess):  return sess.generated
        }
    }

    // MARK: - Custom Codable (discriminator key: "type")

    private enum CodingKeys: String, CodingKey {
        // discriminator
        case type
        // code / refresh fields
        case state, code, scopes, payload, redirect, ttl, generated
        // device-only fields
        case clientId, deviceCode, userCode, status, lastPolledAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .type)
        switch typeName {
        case AuthSessionType.code.rawValue:
            self = .code(CodeSession(
                state: try container.decode(String.self, forKey: .state),
                code: try container.decode(Code.self, forKey: .code),
                scopes: try container.decode([String].self, forKey: .scopes),
                payload: try container.decodeIfPresent(Payload.self, forKey: .payload),
                redirect: try container.decode(String.self, forKey: .redirect),
                ttl: try container.decodeIfPresent(Int64.self, forKey: .ttl),
                generated: try container.decodeIfPresent(Date.self, forKey: .generated) ?? Date()
            ))
        case AuthSessionType.refresh.rawValue:
            self = .refresh(RefreshSession(
                state: try container.decode(String.self, forKey: .state),
                code: try container.decode(Code.self, forKey: .code),
                scopes: try container.decode([String].self, forKey: .scopes),
                payload: try container.decodeIfPresent(Payload.self, forKey: .payload),
                redirect: try container.decode(String.self, forKey: .redirect),
                ttl: try container.decodeIfPresent(Int64.self, forKey: .ttl),
                generated: try container.decodeIfPresent(Date.self, forKey: .generated) ?? Date()
            ))
        case AuthSessionType.device.rawValue:
            self = .device(DeviceSession(
                clientId: try container.decode(String.self, forKey: .clientId),
                deviceCode: try container.decode(Code.self, forKey: .deviceCode),
                userCode: try container.decode(String.self, forKey: .userCode),
                scopes: try container.decode([String].self, forKey: .scopes),
                payload: try container.decodeIfPresent(Payload.self, forKey: .payload),
                status: try container.decode(DeviceGrantStatus.self, forKey: .status),
                lastPolledAt: try container.decodeIfPresent(Date.self, forKey: .lastPolledAt),
                ttl: try container.decodeIfPresent(Int64.self, forKey: .ttl),
                generated: try container.decodeIfPresent(Date.self, forKey: .generated) ?? Date()
            ))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown AuthSession type: \(typeName)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .code(let session):
            try container.encode(AuthSessionType.code.rawValue, forKey: .type)
            try container.encode(session.state, forKey: .state)
            try container.encode(session.code, forKey: .code)
            try container.encode(session.scopes, forKey: .scopes)
            try container.encodeIfPresent(session.payload, forKey: .payload)
            try container.encode(session.redirect, forKey: .redirect)
            try container.encodeIfPresent(session.ttl, forKey: .ttl)
            try container.encode(session.generated, forKey: .generated)
        case .refresh(let session):
            try container.encode(AuthSessionType.refresh.rawValue, forKey: .type)
            try container.encode(session.state, forKey: .state)
            try container.encode(session.code, forKey: .code)
            try container.encode(session.scopes, forKey: .scopes)
            try container.encodeIfPresent(session.payload, forKey: .payload)
            try container.encode(session.redirect, forKey: .redirect)
            try container.encodeIfPresent(session.ttl, forKey: .ttl)
            try container.encode(session.generated, forKey: .generated)
        case .device(let session):
            try container.encode(AuthSessionType.device.rawValue, forKey: .type)
            try container.encode(session.clientId, forKey: .clientId)
            try container.encode(session.deviceCode, forKey: .deviceCode)
            try container.encode(session.userCode, forKey: .userCode)
            try container.encode(session.scopes, forKey: .scopes)
            try container.encodeIfPresent(session.payload, forKey: .payload)
            try container.encode(session.status, forKey: .status)
            try container.encodeIfPresent(session.lastPolledAt, forKey: .lastPolledAt)
            try container.encodeIfPresent(session.ttl, forKey: .ttl)
            try container.encode(session.generated, forKey: .generated)
        }
    }
}
