# PR #24 Complete Review Comments - Comprehensive TODO List

**Total Comments: 322** (286 unique)

---

## ✅ Category 0: Already Completed (30 comments)

These were addressed in commits `d94eca2` and `e085cfe`:

- [x] SwiftLint file length limits
- [x] Redis mirror configuration (2 files)
- [x] Remove webkitgtk compatibility layer (3 instances)
- [x] Remove commented code
- [x] Resource limits discussion
- [x] Auto-generate secrets (jwtSecret, redisPassword)
- [x] Tooling documentation improvements
- [x] Error messages with installation instructions (5 tools)
- [x] Display function format documentation
- [x] Remove global variable exports
- [x] Dynamic certificate domain generation
- [x] Remove redundant thread-safe comments (3 instances)
- [x] Update Log.swift documentation (request id, login logs)

---

## 📋 Category 1: Remove Public Modifiers (~119 comments)

**Priority: HIGH** - Straightforward refactoring

Files with excessive public modifiers:
- `Sources/Uitsmijter-AuthServer/Authentication/AuthSession.swift` (11 instances)
- `Sources/Uitsmijter-AuthServer/Configuration/CookieConfiguration.swift` (4 instances)
- `Sources/Uitsmijter-AuthServer/Configuration/ApplicationConfiguration.swift` (3 instances)
- `Sources/Uitsmijter-AuthServer/Entities/Client/Client.swift` (6 instances)
- `Sources/Uitsmijter-AuthServer/Entities/Entity.swift` (4 instances)
- `Sources/Uitsmijter-AuthServer/Entities/Tenant/Tenant.swift` (3 instances)
- `Sources/Uitsmijter-AuthServer/Entities/EntityStorage.swift` (1 instance)
- `Sources/Uitsmijter-AuthServer/Authentication/LoginSession.swift` (5 instances)
- `Sources/Uitsmijter-AuthServer/Authentication/TimeToLive.swift` (3 instances)
- `Sources/Uitsmijter-AuthServer/Entities/ResourceLoader/*` (8 instances)
- Many more across the codebase

**Action:** Remove `public` modifier from functions/properties that don't need to be exposed outside the module.

---

## 📋 Category 2: Remove Temporary Test Files (33 comments)

**Priority: HIGHEST** - Quick wins, no code changes needed

Files to delete:
```
Tests/Uitsmijter-AuthServerTests/Client/Client+TenantTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/Array+isNotEmptyTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/Date+MillisecondsTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/JSONDecoder+mainTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/JSONEncoder+mainTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/String+CryptoTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/String+RandomTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/String+RegexTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/String+SlugTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/String+WildcardTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/FoundationExtensions/UUID+emptyTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/JWT/PayloadTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/JWT/SignerTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/JWT/SubjectTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/JWT/TokenTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/Monitoring/PrometheusAdvancedTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/Monitoring/PrometheusBasicTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/Monitoring/PrometheusMetricsTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/OAuth/AuthRequestTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/PropertyWrappers/SynchronisedTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/ResourceLoader/EntityFileLoaderMonitoredTests.swift.tmp
Tests/Uitsmijter-AuthServerTests/ResourceLoader/EntityFileLoaderMonitoredTests.swift
Tests/Uitsmijter-AuthServerTests/ResourceLoader/EntityFileLoaderTests.swift.tmp
Tests/Uitsmijter-AuthServerTests/ResourceLoader/EntityFileLoaderTests.swift
Tests/Uitsmijter-AuthServerTests/ScriptingProvider/JSInputParameterTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/ScriptingProvider/JXContext+IdentTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/Tenant/TenantEncoderTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/Tenant/TenantFindTests.swift.tmp
Tests/Uitsmijter-AuthServerTests/Tenant/TenantFindWildcardTests.swift.tmp
Tests/Uitsmijter-AuthServerTests/Tenant/TenantTests.swift.tmp
Tests/Uitsmijter-AuthServerTests/Tenant/TenantTests.swift
Tests/Uitsmijter-AuthServerTests/UserProfile/CodableProfileBasicTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/UserProfile/CodableProfileEdgeTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/UserProfile/CodableProfileNestedTest.swift.tmp
Tests/Uitsmijter-AuthServerTests/WellKnown/OpenidConfigurationTest.swift.tmp
```

---

## 📋 Category 3: Add Missing Documentation (18 comments)

**Priority: MEDIUM** - Improves maintainability

Files needing documentation:
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+MemoryImpl.swift` (8 functions)
- `Sources/Uitsmijter-AuthServer/Authentification/AuthSessionDelegate.swift` (1 protocol)
- `Sources/Uitsmijter-AuthServer/Entities/ResourceLoader/EntityCRDLoader.swift` (3 functions)
- `Sources/Uitsmijter-AuthServer/Entities/ResourceLoader/EntityFileLoader.swift` (2 functions)
- `Sources/Uitsmijter-AuthServer/Entities/ResourceLoader/TenantTemplateLoader.swift` (1 function)
- `Sources/Uitsmijter-AuthServer/OAuth/TokenRequest.swift` (2 functions)
- `Sources/Uitsmijter-AuthServer/OAuth/TokenResponse.swift` (1 struct)

---

## 📋 Category 4: Remove Debug Code/Comments (14 comments)

**Priority: HIGH** - Clean up before release

### Debug timers to remove:
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:78` - Remove debug timer
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:84` - Remove debug timer

### Debug logging to remove:
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:67` - Remove debug log
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:119` - Remove debug logging
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:97` - Remove this

### Debug session leftovers:
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:128` - Remove leftover
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:131` - Remove leftover
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:193` - Remove refactoring leftover

### Test comments to remove:
- `Tests/Uitsmijter-AuthServerTests/Controllers/InterceptorControllerDifferentTenantsTest_SwiftTesting.swift:32`
- `Tests/Uitsmijter-AuthServerTests/Controllers/InterceptorControllerDifferentTenantsTest_SwiftTesting.swift:8`

### Internal refactoring notices:
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+MemoryImpl.swift:7, 15` - Remove internal notices
- `Sources/Uitsmijter-AuthServer/Authentification/AuthCodeStorage+RedisImpl.swift:6` - Remove internal notice

---

## 📋 Category 5: Code Organization & Refactoring (15 comments)

**Priority: MEDIUM** - Improves code structure

### Move to separate files:
- `Sources/Uitsmijter-AuthServer/Entities/Client/Client.swift:8` - Move error definitions
- `Sources/Uitsmijter-AuthServer/Entities/Client/Client.swift:39` - Move to extra file
- `Sources/Uitsmijter-AuthServer/Entities/Client/Client.swift:55` - Move to ClientProtocol file
- `Sources/Uitsmijter-AuthServer/Entities/Client/Client.swift:65` - Move to extra file
- `Sources/Uitsmijter-AuthServer/Entities/ResourceLoader/EntityLoaderProtocol.swift:9` - Move Error definitions
- `Sources/Uitsmijter-AuthServer/Entities/Tenant/Tenant.swift:384` - Move to Tenant+Hashable
- `Sources/Uitsmijter-AuthServer/Authentication/AuthCodeStorageProtocol.swift:32` - Move to own file

### Remove duplicate code:
- `Sources/Uitsmijter-AuthServer/Controllers/WellKnownController.swift:161, 174` - Move to shared class

### Refactor to Actor:
- `Sources/Uitsmijter-AuthServer/Monitoring/Prometheus.swift:55` - Consider Actor pattern

### Split large files:
- `Sources/Uitsmijter-AuthServer/Configuration/ApplicationConfiguration.swift:1` - Consider splitting

---

## 📋 Category 6: Test Improvements (4 comments)

**Priority: LOW**

- `Tests/Uitsmijter-AuthServerTests/ScriptingProvider/IsClassExistsTest.swift:6` - Add negative test suite "Did class Not Exists"
- `Tests/Uitsmijter-AuthServerTests/Controllers/AuthControllerCodeInsecureFlowTest.swift:164` - Check location header
- `Tests/Uitsmijter-AuthServerTests/Configuration/ApplicationConfigurationTest.swift:26` - Remove this test
- `Tests/e2e/playwright/tests/WellKnown/OpenidConfiguration.spec.ts:114` - Clarify example

---

## 📋 Category 7: Logger Documentation (5 comments)

**Priority: LOW**

- `Sources/Logger/Log.swift:143` - Remove hint (as always)
- `Sources/Logger/Log.swift:156` - Correct this hint
- `Sources/Logger/README.md:15` - Remove useless information till refactoring
- `Sources/Logger/README.md:83` - Check format
- `Sources/Uitsmijter-AuthServer/Http/RequestClientMiddleware.swift:100` - Check if needs to be public

---

## 📋 Category 8: Mass Application Comments (14 comments)

**Context**: Comments like "Also applies to all the functions and variables" indicate bulk changes needed

Files affected:
- `Sources/Uitsmijter-AuthServer/Entities/Tenant/Tenant.swift` (5 locations)
- `Sources/Uitsmijter-AuthServer/JWT/*` (Token, Payload, Subject)
- `Sources/Uitsmijter-AuthServer/Login/*` (LoginForm, PageProperties, LocationContent)
- `Sources/Uitsmijter-AuthServer/OAuth/AuthRequest.swift`
- `Sources/Uitsmijter-AuthServer/Entities/ResourceLoader/*` (5 locations)
- `Sources/Uitsmijter-AuthServer/Http/ResponseError.swift`
- `Sources/Uitsmijter-AuthServer/Monitoring/Prometheus.swift`

**Action Required**: Review the specific line mentioned and apply the same change to all functions/variables in that file/struct.

---

## Summary by Priority

| Priority | Category | Count | Effort |
|----------|----------|-------|--------|
| **HIGHEST** | Remove .tmp files | 33 | 5 min |
| **HIGH** | Remove public modifiers | 119 | 2 hours |
| **HIGH** | Remove debug code | 14 | 30 min |
| **MEDIUM** | Add documentation | 18 | 1 hour |
| **MEDIUM** | Code organization | 15 | 2-4 hours |
| **LOW** | Test improvements | 4 | 1 hour |
| **LOW** | Logger docs | 5 | 30 min |
| **CONTEXT** | Mass application | 14 | Variable |

**Total Remaining: ~292 comments to address**
**Estimated Total Time: 8-12 hours**
