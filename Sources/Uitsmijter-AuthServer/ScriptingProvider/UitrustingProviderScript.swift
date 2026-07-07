import Foundation

/// Generates the JavaScript `UserLoginProvider` for the `uitrusting/v1` predefined
/// provider type.
///
/// The generated script calls Uitrusting's `POST {url}/verify` endpoint with the
/// tenant, username and password, and maps its response
///
/// ```json
/// { "known": true, "valid": true, "subject": "…", "roles": [...],
///   "scopes": [...], "profile": { "email": "…", "name": "…", … } }
/// ```
///
/// onto the Uitsmijter provider interface (`canLogin`, `userProfile`, `role`,
/// `roles`, `scopes`, and the committed `subject`).
enum UitrustingProviderScript {

    /// Build the provider script for a Uitrusting service.
    ///
    /// - Parameters:
    ///   - url: The service base URL or host, e.g. `uitrusting.acme.svc`. A scheme
    ///     is added (`http://`) when missing; `/verify` is appended.
    ///   - token: Optional shared secret sent as the `X-Internal-Token` header.
    /// - Returns: A JavaScript source string defining `UserLoginProvider`.
    static func make(url: String, token: String?) -> String {
        let verifyURL = jsString(verifyEndpoint(from: url))
        let tokenHeader: String
        if let token, !token.isEmpty {
            tokenHeader = "headers[\"X-Internal-Token\"] = \(jsString(token));"
        } else {
            tokenHeader = ""
        }

        return """
        // Auto-generated provider for uitrusting/v1
        class UserLoginProvider {
            canLoginFlag = false;
            subjectId = null;
            userRoles = [];
            userScopes = [];
            userProfileData = {};
            constructor(credentials) {
                const headers = { "Content-Type": "application/json" };
                \(tokenHeader)
                fetch(\(verifyURL), {
                    method: "post",
                    headers: headers,
                    body: JSON.stringify({
                        tenant: credentials.tenant.name,
                        username: credentials.username,
                        password: credentials.password
                    })
                }).then((response) => {
                    try {
                        const data = JSON.parse(response.body);
                        if (response.code == 200 && data.known === true && data.valid === true) {
                            this.canLoginFlag = true;
                            this.subjectId = data.subject;
                            this.userRoles = data.roles || [];
                            this.userScopes = data.scopes || [];
                            this.userProfileData = data.profile || {};
                            return commit({ subject: data.subject });
                        }
                    } catch (e) {
                        console.log("uitrusting/v1: cannot parse verify response: " + e);
                    }
                    commit(false);
                }).catch((err) => {
                    console.log("uitrusting/v1: verify request failed: " + err);
                    commit(false);
                });
            }
            get canLogin() { return this.canLoginFlag; }
            get userProfile() { return this.userProfileData; }
            get role() { return this.userRoles.length ? this.userRoles[0] : "none"; }
            get roles() { return this.userRoles; }
            get scopes() { return this.userScopes; }
        }
        """
    }

    /// Normalize a configured URL/host into a full `…/verify` endpoint.
    private static func verifyEndpoint(from url: String) -> String {
        var base = url
        if !base.hasPrefix("http://") && !base.hasPrefix("https://") {
            base = "http://\(base)"
        }
        if base.hasSuffix("/") {
            base.removeLast()
        }
        return "\(base)/verify"
    }

    /// Encode a Swift string as a safe JavaScript double-quoted string literal.
    private static func jsString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
