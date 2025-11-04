import Foundation
import Vapor
import Logger

struct ResponsibilityDomain: Codable {
    let hash: String?

    init(hash value: String? = nil) {
        hash = value
    }

    /// generate a hash for the cookie name that reflects the tenant and responsibleDomain if relevant (silent Login)
    ///
    /// - Parameter
    ///     - on: Request
    ///     - for: ClientInfo
    /// - Returns: a `CookieDomain` that should be used for the sso cookie.
    static func getResponsibilityDomain(on request: Request, for clientInfo: ClientInfo) -> ResponsibilityDomain {
        guard let tenant = clientInfo.tenant else {
            Log.error("Can not get getCookieHash because no tenant in clientInfo.")
            return ResponsibilityDomain()
        }
        if tenant.config.silent_login == false {
            guard let hash = clientInfo.responsibleDomain.data(using: .utf8)?.sha1().hex else {
                Log.error("Can not create hash for responsibleDomain", requestId: request.id)
                return ResponsibilityDomain()
            }
            Log.info("Hash for responsible domain \(clientInfo.responsibleDomain) = \(hash)")
            return ResponsibilityDomain(hash: hash)
        } else {
            guard let hash = clientInfo.tenant?.name.data(using: .utf8)?.sha1().hex else {
                Log.error("Can not create hash for tenant \(clientInfo.tenant?.name ?? "-")", requestId: request.id)
                return ResponsibilityDomain()
            }
            Log.info("Hash for tenant \(clientInfo.tenant?.name ?? "-") = \(hash)")
            return ResponsibilityDomain(hash: hash)
        }
    }

}

struct ResponsibilityDomainKey: StorageKey {
    typealias Value = ResponsibilityDomain
}

extension Request {
    var responsibilityDomain: ResponsibilityDomain? {
        get {
            storage[ResponsibilityDomainKey.self]
        }
        set {
            storage[ResponsibilityDomainKey.self] = newValue
        }
    }
}
