# Actor Conversion Analysis Report

This document analyzes classes and structs in the Uitsmijter codebase that could benefit from Actor implementation, focusing on concurrency safety and shared mutable state patterns.

Generated: 2025-10-21


---

## High Priority

### 3. Prometheus
**Location:** `Sources/Uitsmijter-AuthServer/Monitoring/Prometheus.swift`

**Current State:**
- Multiple `nonisolated(unsafe)` global metric variables
- Singleton pattern with shared metrics client
- No synchronization for metric updates

**Advantages of Converting to Actor:**
- ✅ Safe concurrent metric updates from multiple threads
- ✅ Eliminates all `nonisolated(unsafe)` globals
- ✅ Clear ownership of metrics state
- ✅ Can batch metric updates efficiently
- ✅ Better testability with isolated state

**Disadvantages:**
- ❌ Metric increments become async operations
- ❌ May add latency to hot paths (login, OAuth flows)
- ❌ PrometheusClient library might not be Sendable
- ❌ Widespread usage means many call sites to update

**Recommendation:** **MEDIUM-HIGH - Create Actor Wrapper**. Create a `MetricsActor` to wrap the unsafe globals rather than converting the struct itself. This allows keeping synchronous increment APIs with internal actor coordination.


---

### 7. TranslationTag/TranslationProvider
**Location:** `Sources/Uitsmijter-AuthServer/Tags/`

**Files:**
- `TranslationTag.swift`
- `TranslationProvider.swift`

**Current State:**
- `nonisolated(unsafe) static let provider`
- Immutable translation dictionary

**Advantages of Converting to Actor:**
- ✅ Safe static singleton access
- ✅ Could support dynamic translation reloading
- ✅ Removes unsafe annotation

**Disadvantages:**
- ❌ Provider is immutable after initialization (already safe)
- ❌ Leaf template rendering expects synchronous access
- ❌ No actual concurrency issues with read-only data
- ❌ Would complicate template tag API

**Recommendation:** **LOW - Use Safe Initialization Pattern**. Since the data is immutable, use a proper once-initialized pattern or `static let` without unsafe annotation. Actor conversion not needed.

---

## Implementation Notes

### Key Findings

**Classes Most Needing Actor Isolation:**
1. **JavaScriptProvider** - No current thread-safety with mutable `committedResults`
2. **MemoryAuthCodeStorage** - Unsafe mutable state with concurrent garbage collection
3. **Prometheus** - Excessive use of `nonisolated(unsafe)` global metric variables

**Already Properly Isolated:**
- EntityStorage (`@MainActor`)
- TenantTemplateLoader (`actor`)
- RequestClientMiddleware (explicit `MainActor.run`)

**Using Deprecated Patterns:**
- Multiple uses of `@unchecked Sendable` to bypass compiler safety
- Mix of `@MainActor` and `nonisolated(unsafe)` in same classes
- NSLock-based property wrapper where Actor would be cleaner

### Migration Strategy

When converting classes to Actors:

1. **Phase 1 - Critical Safety Issues**
   - Convert JavaScriptProvider to actor
   - Convert MemoryAuthCodeStorage to actor
   - These have actual concurrency bugs waiting to happen

2. **Phase 2 - Code Quality Improvements**
   - Wrap Prometheus metrics in actor
   - Clean up EntityLoader unsafe annotations
   - Document RedisAuthCodeStorage thread-safety guarantees

3. **Phase 3 - Polish**
   - Simplify EntityFileLoader handler annotations
   - Improve TranslationProvider initialization pattern
   - Consider deprecating `@Synchronised` property wrapper in favor of actors

### Testing Strategy

After Actor conversion:
- Verify all tests pass with strict concurrency checking enabled
- Add concurrency stress tests for converted actors
- Profile performance impact of async actor calls
- Document any breaking API changes

---

## Additional Synchronization Utilities Found

### Synchronised<T>
**Location:** `Sources/Uitsmijter-AuthServer/PropertyWrappers/Synchronised.swift`

**Type:** Generic property wrapper struct using `NSLock()`

**Usage:** Used by `MemoryAuthCodeStorage` for `loginSessions`

**Status:** Well-implemented lock-based synchronization, but older pattern. Could be replaced with Actor isolation in Swift 6.2.

### UnsafeTransfer<T>
**Location:** `Sources/Uitsmijter-AuthServer/Utilities/UnsafeTransfer.swift`

**Type:** Generic wrapper with `@unchecked Sendable`

**Purpose:** Bridges non-Sendable types across concurrency boundaries

**Usage:** Used to transfer `FileChange` events from FileMonitor

**Status:** Documented with clear warnings about responsibility. Acceptable pattern when interfacing with non-Sendable APIs.

---

## Conclusion

The three critical candidates (**JavaScriptProvider**, **MemoryAuthCodeStorage**, **Prometheus**) would benefit most from Actor conversion, as they currently rely on unsafe annotations or manual synchronization that Swift's Actor model handles better.

The codebase shows good awareness of concurrency concerns with extensive use of `@MainActor` and some Actor usage. The main improvements needed are:
- Replacing unsafe escape hatches with proper Actor isolation
- Standardizing on Swift concurrency primitives over manual locks
- Ensuring all shared mutable state is properly isolated

### Progress Update (2025-10-25)

**✅ Completed:**
- **EntityLoader** (commit f99a1ca, 2025-10-24): Successfully removed `nonisolated(unsafe)` annotation and confirmed `@MainActor` is the correct design pattern. Decision rationale documented above.
- **MemoryAuthCodeStorage** (2025-10-25): Converted to `actor`, removed all unsafe annotations and `@Synchronised` wrapper
- **RedisAuthCodeStorage** (2025-10-25): Converted to `actor`, removed `@unchecked Sendable` and DispatchQueue usage
- **AuthCodeStorageProtocol** (2025-10-25): Updated to async methods for actor compatibility
- **All Call Sites** (2025-10-25): Updated AuthorizeController, LoginController, LogoutController, TokenController, HealthController to use `await`

**🔄 In Progress:**
- **EntityCRDLoader**: Added retry logic with exponential backoff for Kubernetes API readiness (commit f99a1ca)

**⏳ Remaining Critical Work:**
- JavaScriptProvider → Actor conversion
- Prometheus → Create Actor wrapper for metrics
