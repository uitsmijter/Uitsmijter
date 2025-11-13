# Migration Plan: jwt-kit v4 → v5 (BoringSSL → SwiftCrypto)

**Date:** November 12, 2025
**Author:** Claude Code
**Status:** Planning
**Estimated Effort:** 2-3 hours + 1-2 hours testing

## Executive Summary

Migrate from jwt-kit v4 (BoringSSL-based) to v5 (SwiftCrypto-based) to resolve persistent module conflicts between `CJWTKitBoringSSL` and `CNIOBoringSSL` that are blocking CI builds.

## Why This Migration?

### Current Problem
- **CI Build Failure:** All CI builds fail with BoringSSL module conflicts
- **Root Cause:** jwt-kit 4.13.5 uses CJWTKitBoringSSL; swift-nio-ssl 2.35.0 uses CNIOBoringSSL
- **Error Example:**
  ```
  error: 'BASIC_CONSTRAINTS_st' has different definitions in different modules
  ```

### Solution Benefits
✅ **Eliminates BoringSSL conflicts** permanently
✅ **Future-proof:** Aligns with Vapor ecosystem direction
✅ **Modern APIs:** SwiftCrypto provides native Swift cryptography
✅ **Better performance:** No C interop overhead
✅ **Async/await:** jwt-kit v5 uses modern concurrency

## Migration Phases

### Phase 1: Dependency Update (30 minutes)

#### 1.1 Update Package.swift
```swift
// Change from:
.package(url: "https://github.com/vapor/jwt.git", from: "4.1.0"),

// To:
.package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"),
```

#### 1.2 Add _CryptoExtras Dependency
```swift
dependencies: [
    // ... existing dependencies
    .product(name: "JWT", package: "jwt"),
    .product(name: "_CryptoExtras", package: "swift-crypto"), // Add this
],
```

#### 1.3 Resolve Packages
```bash
./tooling.sh build  # This will resolve to jwt-kit 5.2.0
```

**Expected Result:**
- jwt-kit: 4.13.5 → 5.2.0
- Package.resolved updated with SwiftCrypto dependencies

---

### Phase 2: Rewrite KeyGenerator.swift (1-2 hours)

Current file uses BoringSSL C APIs. Must be rewritten to use SwiftCrypto.

#### 2.1 Import Changes

**Before:**
```swift
import CJWTKitBoringSSL
import Foundation
import JWTKit
```

**After:**
```swift
import Foundation
import JWTKit
import _CryptoExtras  // For _RSA APIs
import Crypto         // For base crypto types
```

#### 2.2 Key Generation Method Rewrite

**Current BoringSSL Approach:**
```swift
func generateKeyPair(kid: String) async throws -> RSAKeyPair {
    // 88 lines of C API calls with BN, EVP_PKEY, BIO, etc.
}
```

**New SwiftCrypto Approach:**
```swift
import _CryptoExtras

func generateKeyPair(kid: String) async throws -> RSAKeyPair {
    // Generate RSA private key (2048-bit minimum enforced by API)
    let privateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)

    // Extract public key
    let publicKey = privateKey.publicKey

    // Export to PEM format
    let privateKeyPEM = try privateKey.pemRepresentation
    let publicKeyPEM = publicKey.pemRepresentation

    return RSAKeyPair(
        privateKeyPEM: privateKeyPEM,
        publicKeyPEM: publicKeyPEM,
        kid: kid
    )
}
```

**Key Differences:**
- ✅ No manual memory management (no `defer { free() }`)
- ✅ No C pointer juggling
- ✅ Type-safe Swift APIs
- ✅ Built-in PEM serialization
- ✅ Automatic 2048-bit minimum enforcement

#### 2.3 JWK Conversion Rewrite

**Current BoringSSL Approach:**
```swift
nonisolated func convertToJWK(keyPair: RSAKeyPair) throws -> RSAPublicJWK {
    // Load PEM, extract RSA components, convert to bytes, base64url encode
    // ~80 lines of C API calls
}
```

**New SwiftCrypto Approach:**
```swift
nonisolated func convertToJWK(keyPair: RSAKeyPair) throws -> RSAPublicJWK {
    // Parse PEM to get public key
    let publicKey = try _RSA.Signing.PublicKey(pemRepresentation: keyPair.publicKeyPEM)

    // SwiftCrypto provides direct access to key components
    // Convert to JWK format
    let modulus = publicKey.modulus  // Already in Data format
    let exponent = publicKey.exponent  // Already in Data format

    // Base64url encode (no padding)
    let base64urlN = base64URLEncode(modulus)
    let base64urlE = base64URLEncode(exponent)

    return RSAPublicJWK(
        kty: "RSA",
        use: "sig",
        kid: keyPair.kid,
        alg: keyPair.algorithm,
        n: base64urlN,
        e: base64urlE
    )
}
```

**Note:** May need to check actual _RSA.Signing.PublicKey API for exact property names.

#### 2.4 Remove Helper Methods

These BoringSSL-specific helpers can be deleted:
- `exportPrivateKeyPEM(pkey:)`
- `exportPublicKeyPEM(pkey:)`
- `readBIOToString(bio:)`
- `loadPublicKeyPEM(pem:)`

The `base64URLEncode()` helper can stay unchanged.

#### 2.5 Updated KeyGenerator Structure

**Final Implementation:**
```swift
import _CryptoExtras
import Foundation
import JWTKit

/// RSA Key Pair Generator using SwiftCrypto
///
/// Generates RSA key pairs for asymmetric JWT signing according to RFC 7517.
/// Uses Swift's native _CryptoExtras for secure, type-safe key generation.
///
/// - Note: Migrated from BoringSSL to SwiftCrypto in jwt-kit v5
actor KeyGenerator {

    static let shared = KeyGenerator()

    struct RSAKeyPair: Sendable {
        let privateKeyPEM: String
        let publicKeyPEM: String
        let kid: String
        let algorithm: String = "RS256"
    }

    init() {}

    /// Generate a new RSA key pair using SwiftCrypto
    func generateKeyPair(kid: String) async throws -> RSAKeyPair {
        let privateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let publicKey = privateKey.publicKey

        let privateKeyPEM = try privateKey.pemRepresentation
        let publicKeyPEM = publicKey.pemRepresentation

        return RSAKeyPair(
            privateKeyPEM: privateKeyPEM,
            publicKeyPEM: publicKeyPEM,
            kid: kid
        )
    }

    /// Convert multiple key pairs to JWK Set
    nonisolated func convertToJWKSet(_ keyPairs: [RSAKeyPair]) throws -> JWKSet {
        var jwks: [RSAPublicJWK] = []
        for keyPair in keyPairs {
            let jwk = try convertToJWK(keyPair: keyPair)
            jwks.append(jwk)
        }
        return JWKSet(keys: jwks)
    }

    /// Convert public key to JWK format
    nonisolated func convertToJWK(keyPair: RSAKeyPair) throws -> RSAPublicJWK {
        let publicKey = try _RSA.Signing.PublicKey(pemRepresentation: keyPair.publicKeyPEM)

        // Extract key components (API may vary - needs verification)
        let modulus = try extractModulus(from: publicKey)
        let exponent = try extractExponent(from: publicKey)

        return RSAPublicJWK(
            kty: "RSA",
            use: "sig",
            kid: keyPair.kid,
            alg: keyPair.algorithm,
            n: base64URLEncode(modulus),
            e: base64URLEncode(exponent)
        )
    }

    // Helper methods to extract RSA components
    // Implementation depends on _CryptoExtras API

    private nonisolated func base64URLEncode(_ data: Data) -> String {
        var base64 = data.base64EncodedString()
        base64 = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64
    }
}

// Error types remain unchanged
enum KeyGenerationError: Error, CustomStringConvertible {
    case insufficientEntropy
    case invalidKeySize
    case generationFailed(String)

    var description: String {
        switch self {
        case .insufficientEntropy:
            return "Insufficient system entropy for key generation"
        case .invalidKeySize:
            return "Invalid RSA key size specified"
        case .generationFailed(let reason):
            return "Key generation failed: \(reason)"
        }
    }
}

enum ConversionError: Error, CustomStringConvertible {
    case invalidKeyFormat
    case extractionFailed(String)

    var description: String {
        switch self {
        case .invalidKeyFormat:
            return "Invalid key format for JWK conversion"
        case .extractionFailed(let reason):
            return "Key component extraction failed: \(reason)"
        }
    }
}
```

**⚠️ Research Required:**
The exact API for extracting RSA modulus and exponent from `_RSA.Signing.PublicKey` needs verification. Check:
1. Does `_CryptoExtras` expose these properties directly?
2. Do we need to use DER encoding and parse it?
3. Can we use jwt-kit's internal utilities?

---

### Phase 3: Update Signer/Token Usage (30 minutes)

#### 3.1 Update SignerManager.swift

**Check for jwt-kit v5 Changes:**
- `JWTKeyCollection` is now an `actor`
- All methods are `async`
- Key adding methods return `JWTKeyIdentifier`

**Before:**
```swift
keys.add(rsa: privateKey, digestAlgorithm: .sha256, kid: kid)
```

**After:**
```swift
await keys.add(rsa: privateKey, digestAlgorithm: .sha256, kid: .string(kid))
```

#### 3.2 Update Token.swift

Check if JWT signing/verification needs async updates:
```swift
// May need to add await
let token = try await req.jwt.sign(payload)
```

#### 3.3 Update WellKnownController.swift

No changes expected (already async), but verify JWKS endpoint still works.

---

### Phase 4: Testing Strategy (1-2 hours)

#### 4.1 Unit Tests

**Critical Tests:**
- `KeyGeneratorTest.swift` - All tests must pass
- `KeyStorageTest.swift` - All 22 tests must pass (including the fixed deadlock test)
- `SignerManagerTest.swift` - JWT signing/verification
- `TokenTest.swift` - Token generation
- `WellKnownJWKSTest.swift` - JWKS endpoint

**Run:**
```bash
./tooling.sh test
```

**Expected:** All tests pass, build time ~30-40 seconds (similar to current)

#### 4.2 Integration Tests

**Test Key Rotation:**
```bash
./tooling.sh test KeyStorageTest.keyRotationScenario
```

**Test JWK Export:**
```bash
./tooling.sh test WellKnownJWKSTest
```

#### 4.3 E2E Tests

**Full E2E Suite:**
```bash
./tooling.sh e2e
```

**Expected:** All OAuth flows work with new keys

#### 4.4 Manual Verification

1. **Generate a new key:**
   ```bash
   # In swift repl or test
   let generator = KeyGenerator()
   let pair = try await generator.generateKeyPair(kid: "test-2025")
   print(pair.privateKeyPEM)
   ```

2. **Verify PEM format:**
   - Private key starts with `-----BEGIN PRIVATE KEY-----`
   - Public key starts with `-----BEGIN PUBLIC KEY-----`
   - Both are valid PKCS#8 format

3. **Test JWT signing:**
   - Sign a test token
   - Verify on jwt.io
   - Confirm algorithm is RS256

---

### Phase 5: CI/CD Validation (30 minutes)

#### 5.1 Local Docker Build

```bash
./tooling.sh build
./tooling.sh test
```

**Expected:** No BoringSSL errors

#### 5.2 Push and Monitor CI

```bash
git add .
git commit -m "Migrate to jwt-kit v5 (SwiftCrypto)"
git push
gh run watch
```

**Expected:** All CI jobs pass (lint, test, build, e2e)

---

## Risk Assessment

### High Risk
- ❌ **JWK extraction API unknown** - Need to verify _CryptoExtras provides modulus/exponent access
  - **Mitigation:** Research jwt-kit source code, or use DER parsing fallback

### Medium Risk
- ⚠️ **Breaking API changes** - jwt-kit v5 has async actor-based KeyCollection
  - **Mitigation:** Comprehensive testing, check all jwt.sign() call sites

### Low Risk
- ✅ **PEM format differences** - SwiftCrypto uses same PKCS#8 format
- ✅ **Key size enforcement** - SwiftCrypto enforces 2048-bit minimum (same as current)
- ✅ **Algorithm support** - RS256 fully supported

---

## Rollback Plan

If migration fails:

1. **Revert Package.swift:**
   ```bash
   git checkout main -- Package.swift Package.resolved
   swift package resolve
   ```

2. **Revert KeyGenerator.swift:**
   ```bash
   git checkout main -- Sources/Uitsmijter-AuthServer/JWT/KeyGenerator.swift
   ```

3. **Rebuild:**
   ```bash
   ./tooling.sh build
   ./tooling.sh test
   ```

---

## Pre-Migration Checklist

Before starting migration:

- [ ] Commit current working state
- [ ] Create feature branch: `feature/migrate-jwt-v5`
- [ ] Ensure all current tests pass
- [ ] Backup existing keys (if production)
- [ ] Review jwt-kit v5 changelog
- [ ] Research _CryptoExtras RSA API details
- [ ] Allocate 3-4 hours of focused time

---

## Post-Migration Checklist

After migration complete:

- [ ] All unit tests pass
- [ ] All E2E tests pass
- [ ] CI build succeeds
- [ ] No BoringSSL errors in logs
- [ ] JWT tokens verify on jwt.io
- [ ] JWKS endpoint returns valid JSON
- [ ] Key rotation works
- [ ] Documentation updated
- [ ] CHANGELOG.md entry added

---

## Open Questions

1. **_CryptoExtras API:** Does `_RSA.Signing.PublicKey` expose `.modulus` and `.exponent` properties directly?
   - **Research:** Check swift-crypto source code
   - **Alternative:** Parse DER encoding if properties not exposed

2. **jwt-kit v5 Compatibility:** Are there breaking changes in JWT signing/verification APIs?
   - **Research:** Review jwt-kit 5.0.0 migration guide
   - **Test:** Run existing tests and fix compile errors

3. **Performance:** Is SwiftCrypto RSA generation faster/slower than BoringSSL?
   - **Measure:** Time 100 key generations before and after

---

## Resources

- jwt-kit v5 Blog: https://blog.vapor.codes/posts/jwtkit-v5/
- jwt-kit Repo: https://github.com/vapor/jwt-kit
- swift-crypto Repo: https://github.com/apple/swift-crypto
- _CryptoExtras Docs: https://github.com/apple/swift-crypto/tree/main/Sources/_CryptoExtras
- RFC 7517 (JWKS): https://www.rfc-editor.org/rfc/rfc7517

---

## Timeline

**Total Estimated Time: 4-5 hours**

| Phase | Task | Duration |
|-------|------|----------|
| 1 | Dependency Update | 30 min |
| 2 | KeyGenerator Rewrite | 1-2 hours |
| 3 | Update Other Files | 30 min |
| 4 | Testing | 1-2 hours |
| 5 | CI Validation | 30 min |

**Recommended Approach:**
- Day 1: Research + Phase 1-2 (2-3 hours)
- Day 2: Phase 3-5 (2 hours)

---

## Success Criteria

✅ All unit tests pass
✅ All E2E tests pass
✅ CI builds successfully
✅ No BoringSSL errors in logs
✅ JWT tokens work identically to before
✅ JWKS endpoint works
✅ Key rotation works
✅ Performance is acceptable (within 10% of current)

---

**Next Steps:**
1. Review and approve this plan
2. Create feature branch
3. Research _CryptoExtras API details
4. Execute Phase 1
