import Foundation

/// Generates the JavaScript `UserLoginProvider` + `UserValidationProvider` for the
/// `uitrusting/v1` predefined provider type.
///
/// Both call Uitrusting's single `POST {url}/verify` endpoint:
/// - **Login** sends `{ tenant, username, password_hash }` (SHA256 hex — the plain
///   password is never transmitted); `valid` means the credentials are correct.
/// - **Refresh re-validation** sends `{ tenant, username }` with no hash; `valid`
///   then means the user still exists and is active.
///
/// The status code is always 200, so the decision is made on `valid`, and the
/// response maps
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

        // Login: POST { username, password_hash, tenant } to /verify.
        // `valid` means the credentials are correct. The status is always 200, so we
        // decide on `valid` (and `known`), never the HTTP status code. The password is
        // never sent in the clear — only its SHA256 hex hash.
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
                        password_hash: sha256(credentials.password)
                    })
                }).then((response) => {
                    try {
                        const data = JSON.parse(response.body);
                        if (data.known === true && data.valid === true) {
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

        // Refresh re-validation: POST { username, tenant } (no password_hash) to the
        // same /verify. With no hash, `valid` means the user still exists and is active.
        class UserValidationProvider {
            validFlag = false;
            constructor(args) {
                const headers = { "Content-Type": "application/json" };
                \(tokenHeader)
                fetch(\(verifyURL), {
                    method: "post",
                    headers: headers,
                    body: JSON.stringify({
                        tenant: args.tenant.name,
                        username: args.username
                    })
                }).then((response) => {
                    try {
                        const data = JSON.parse(response.body);
                        this.validFlag = (data.valid === true);
                    } catch (e) {
                        console.log("uitrusting/v1: cannot parse verify response: " + e);
                    }
                    commit(this.validFlag);
                }).catch((err) => {
                    console.log("uitrusting/v1: verify request failed: " + err);
                    commit(false);
                });
            }
            get isValid() { return this.validFlag; }
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
