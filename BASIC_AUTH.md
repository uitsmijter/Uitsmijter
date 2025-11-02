# Basic Auth Implementation Plan for Token Endpoint

## Current Status

As of the analysis performed on 2025-11-02, the OpenID Discovery metadata advertises three token endpoint authentication methods:

```swift
// OpenidConfigurationBuilder.swift:84-88
private static let defaultTokenEndpointAuthMethods = [
    "client_secret_post",   // ✅ IMPLEMENTED
    "client_secret_basic",  // ❌ NOT IMPLEMENTED (removed from discovery)
    "none"                  // ✅ IMPLEMENTED
]
```

However, only `client_secret_post` and `none` are actually implemented in TokenController.swift.

**Action Taken:** Removed `client_secret_basic` from the advertised methods to accurately reflect current capabilities.

## Implementation Plan for Basic Auth Support

When implementing `client_secret_basic` authentication in the future, follow these steps:

### 1. Understanding OAuth 2.0 Basic Authentication

Per [RFC 6749 Section 2.3.1](https://tools.ietf.org/html/rfc6749#section-2.3.1), clients using `client_secret_basic` must:

1. Construct credentials as `client_id:client_secret`
2. Base64-encode the credentials
3. Send via HTTP header: `Authorization: Basic <base64-encoded-credentials>`

Example:
```
Client ID: my-app-id
Client Secret: my-secret-123
Credentials: my-app-id:my-secret-123
Base64: bXktYXBwLWlkOm15LXNlY3JldC0xMjM=
Header: Authorization: Basic bXktYXBwLWlkOm15LXNlY3JldC0xMjM=
```

### 2. Implementation Steps

#### Phase 1: Add Basic Auth Parsing Utility

Create a new extension or utility in `Sources/Uitsmijter-AuthServer/Http/` to parse Basic Auth:

```swift
// Request+BasicAuth.swift
import Vapor

extension Request {
    /// Extracts Basic Auth credentials from the Authorization header.
    ///
    /// - Returns: Tuple of (username, password) if valid Basic Auth, nil otherwise
    func basicAuthCredentials() -> (username: String, password: String)? {
        guard let authorization = headers.first(name: .authorization) else {
            return nil
        }

        guard authorization.hasPrefix("Basic ") else {
            return nil
        }

        let base64String = authorization.dropFirst("Basic ".count)
        guard let data = Data(base64Encoded: String(base64String)),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }

        let components = decoded.split(separator: ":", maxSplits: 1)
        guard components.count == 2 else {
            return nil
        }

        return (username: String(components[0]), password: String(components[1]))
    }
}
```

#### Phase 2: Modify TokenRequest Decoding

Update the token request handling to support credentials from either source:

**Option A: Custom Decoder**

Implement a custom `Content` decoder for `TokenRequest` that checks both POST body and Authorization header:

```swift
// TokenRequest+Decode.swift
extension TokenRequest {
    /// Decodes a TokenRequest from either POST body or Basic Auth header.
    ///
    /// Priority:
    /// 1. POST body client_id and client_secret (if present)
    /// 2. Authorization Basic header (if POST body doesn't contain credentials)
    static func decode(from req: Request) throws -> TokenRequest {
        var tokenRequest = try req.content.decode(TokenRequest.self)

        // If client_secret not in POST body, try Basic Auth
        if tokenRequest.client_secret == nil,
           let (clientId, clientSecret) = req.basicAuthCredentials() {
            // Verify client_id matches
            if tokenRequest.client_id != clientId {
                throw Abort(.badRequest, reason: "ERROR.CLIENT_ID_MISMATCH")
            }
            tokenRequest.client_secret = clientSecret
        }

        return tokenRequest
    }
}
```

**Option B: Middleware Approach**

Create middleware that pre-populates request content with Basic Auth credentials before TokenController processes it.

#### Phase 3: Update TokenController

Modify `TokenController.requestToken` to use the new decoding:

```swift
// Before (line 87):
let tokenRequest = try req.content.decode(TokenRequest.self)

// After:
let tokenRequest = try TokenRequest.decode(from: req)
```

#### Phase 4: Client Configuration

**IMPORTANT:** Clients MUST explicitly configure which authentication method they support.

Add a new field to the Client configuration:

```swift
// Client.swift or ClientConfig.swift
struct ClientConfig {
    // ... existing fields ...

    /// Supported token endpoint authentication methods for this client.
    ///
    /// Valid values:
    /// - "client_secret_post": Client credentials in POST body (default)
    /// - "client_secret_basic": Client credentials in Authorization header
    /// - "none": Public client without authentication
    ///
    /// If not specified, defaults to ["client_secret_post", "none"]
    var token_endpoint_auth_methods: [String]?
}
```

Update the authentication logic in TokenController:

```swift
// Determine which auth method was used
let authMethod: String
if tokenRequest.client_secret != nil {
    if req.headers.first(name: .authorization)?.hasPrefix("Basic ") == true {
        authMethod = "client_secret_basic"
    } else {
        authMethod = "client_secret_post"
    }
} else {
    authMethod = "none"
}

// Verify client supports this auth method
let supportedMethods = client.config.token_endpoint_auth_methods
    ?? ["client_secret_post", "none"]

if !supportedMethods.contains(authMethod) {
    throw Abort(.unauthorized, reason: "ERROR.UNSUPPORTED_AUTH_METHOD")
}
```

#### Phase 5: Update OpenID Discovery

Only advertise `client_secret_basic` if at least one client supports it:

```swift
// OpenidConfigurationBuilder.swift
func build(for tenant: Tenant, request: Request, storage: EntityStorage) -> OpenidConfiguration {
    // ... existing code ...

    let tenantClients = storage.clients.filter { client in
        client.config.tenantname == tenant.name
    }

    // Aggregate supported auth methods from all tenant clients
    let supportedAuthMethods = aggregateTokenEndpointAuthMethods(from: tenantClients)

    return OpenidConfiguration(
        // ... other fields ...
        token_endpoint_auth_methods_supported: supportedAuthMethods,
        // ... other fields ...
    )
}

private func aggregateTokenEndpointAuthMethods(from clients: [Client]) -> [String] {
    var allMethods = Set<String>()

    for client in clients {
        let clientMethods = client.config.token_endpoint_auth_methods
            ?? ["client_secret_post", "none"]
        allMethods.formUnion(clientMethods)
    }

    // Always support these as baseline
    if allMethods.isEmpty {
        return ["client_secret_post", "none"]
    }

    return Array(allMethods).sorted()
}
```

#### Phase 6: Add Tests

Create comprehensive tests in `Tests/Uitsmijter-AuthServerTests/Controllers/`:

```swift
// TokenControllerBasicAuthTest.swift

@Suite("Token Controller Basic Auth Tests")
@MainActor
struct TokenControllerBasicAuthTest {

    @Test("Basic Auth with valid credentials grants token")
    func basicAuthValidCredentials() async throws {
        // Setup client with secret
        // Send request with Authorization: Basic header
        // Verify token is granted
    }

    @Test("Basic Auth with invalid credentials returns 401")
    func basicAuthInvalidCredentials() async throws {
        // Send request with wrong credentials in Basic Auth
        // Verify 401 Unauthorized
    }

    @Test("Basic Auth client_id mismatch returns 400")
    func basicAuthClientIdMismatch() async throws {
        // Send POST body with client_id=A
        // Send Basic Auth with client_id=B
        // Verify 400 Bad Request
    }

    @Test("Client without basic auth support rejects Basic Auth")
    func clientRejectsUnsupportedAuthMethod() async throws {
        // Configure client with token_endpoint_auth_methods = ["client_secret_post"]
        // Send request with Basic Auth
        // Verify 401 Unauthorized
    }

    @Test("Malformed Basic Auth header returns 400")
    func malformedBasicAuthHeader() async throws {
        // Send Authorization: Basic <invalid-base64>
        // Verify 400 Bad Request
    }

    @Test("POST body credentials take precedence over Basic Auth")
    func postBodyTakesPrecedence() async throws {
        // Send both POST body client_secret AND Basic Auth
        // Verify POST body credentials are used
    }
}
```

#### Phase 7: Update Documentation

Update the following documentation:

1. **API Documentation**: Document the two ways to authenticate
2. **Client Configuration Guide**: Explain `token_endpoint_auth_methods` setting
3. **Security Best Practices**: Recommend Basic Auth over POST for confidential clients
4. **Migration Guide**: Help existing clients adopt Basic Auth

### 3. Security Considerations

- **TLS Required**: Basic Auth MUST only be accepted over HTTPS/TLS connections
- **Credential Validation**: Same validation as `client_secret_post`
- **Rate Limiting**: Apply same rate limits to prevent brute force
- **Logging**: Log authentication method used (but not credentials)

### 4. Compatibility Notes

- **Backwards Compatible**: Existing clients using `client_secret_post` continue to work
- **RFC 6749 Compliance**: Improves OAuth 2.0 standards compliance
- **Client Libraries**: Many OAuth client libraries default to Basic Auth, so this improves interoperability

### 5. Testing Checklist

- [ ] Unit tests for `basicAuthCredentials()` utility
- [ ] Integration tests for TokenController with Basic Auth
- [ ] Test client_id mismatch scenarios
- [ ] Test malformed Authorization headers
- [ ] Test precedence (POST body vs Basic Auth)
- [ ] Test client auth method restrictions
- [ ] Test OpenID Discovery aggregation
- [ ] E2E tests with real OAuth clients

### 6. Future Enhancements

After Basic Auth is implemented:

- Consider supporting `client_secret_jwt` (JWT-based client authentication)
- Consider supporting `private_key_jwt` (public key authentication)
- Add client authentication method to metrics for observability

## References

- [RFC 6749: OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
- [RFC 6749 Section 2.3.1: Client Password](https://tools.ietf.org/html/rfc6749#section-2.3.1)
- [OpenID Connect Core 1.0: Client Authentication](https://openid.net/specs/openid-connect-core-1_0.html#ClientAuthentication)
- [RFC 7617: HTTP Basic Authentication Scheme](https://tools.ietf.org/html/rfc7617)

---

**Note:** This implementation should be prioritized based on actual client needs. If all current clients successfully use `client_secret_post`, Basic Auth support can be deferred until a client specifically requires it.
