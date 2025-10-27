import Foundation
@testable import Uitsmijter_AuthServer
import Testing

/// Tests for CookieConfiguration
@Suite("CookieConfiguration Tests")
struct CookieConfigurationTest {

    // MARK: - CookieConfiguration Tests

    @Test("CookieConfiguration isSecure is accessible")
    func isSecureIsAccessible() {
        let value = CookieConfiguration.isSecure
        // Verify it's a valid Bool (either true or false)
        #expect(value == true || value == false)
    }

    @Test("CookieConfiguration isHTTPOnly is true by default")
    func isHTTPOnlyIsTrueByDefault() {
        #expect(CookieConfiguration.isHTTPOnly == true)
    }

    @Test("CookieConfiguration sameSitePolicy is strict by default")
    func sameSitePolicyIsStrictByDefault() {
        #expect(CookieConfiguration.sameSitePolicy == .strict)
    }

    @Test("CookieConfiguration defaultPath is root")
    func defaultPathIsRoot() {
        #expect(CookieConfiguration.defaultPath == "/")
    }

    // MARK: - CookieSameSitePolicy Tests

    @Test("CookieSameSitePolicy strict has correct raw value")
    func strictHasCorrectRawValue() {
        #expect(CookieSameSitePolicy.strict.rawValue == "Strict")
    }

    @Test("CookieSameSitePolicy lax has correct raw value")
    func laxHasCorrectRawValue() {
        #expect(CookieSameSitePolicy.lax.rawValue == "Lax")
    }

    @Test("CookieSameSitePolicy noRestriction has correct raw value")
    func noRestrictionHasCorrectRawValue() {
        #expect(CookieSameSitePolicy.noRestriction.rawValue == "None")
    }

    @Test("CookieSameSitePolicy is Sendable")
    func isSendable() async {
        let policy = CookieSameSitePolicy.strict
        await Task {
            #expect(policy == .strict)
        }.value
    }

    // MARK: - CookieSettings Tests

    @Test("CookieSettings initializes with all parameters")
    func initializesWithAllParameters() {
        let expires = Date().addingTimeInterval(3600)
        let settings = CookieSettings(
            content: "test_value",
            expires: expires,
            isSecure: true,
            isHTTPOnly: true,
            sameSite: .lax,
            path: "/custom"
        )

        #expect(settings.content == "test_value")
        #expect(settings.expires == expires)
        #expect(settings.isSecure == true)
        #expect(settings.isHTTPOnly == true)
        #expect(settings.sameSite == .lax)
        #expect(settings.path == "/custom")
    }

    @Test("CookieSettings uses default values when not specified")
    func usesDefaultValues() {
        let expires = Date().addingTimeInterval(3600)
        let settings = CookieSettings(
            content: "test_value",
            expires: expires
        )

        #expect(settings.content == "test_value")
        #expect(settings.expires == expires)
        #expect(settings.isSecure == CookieConfiguration.isSecure)
        #expect(settings.isHTTPOnly == CookieConfiguration.isHTTPOnly)
        #expect(settings.sameSite == CookieConfiguration.sameSitePolicy)
        #expect(settings.path == CookieConfiguration.defaultPath)
    }

    @Test("CookieSettings.default creates instance with defaults")
    func defaultCreatesInstanceWithDefaults() {
        let expires = Date().addingTimeInterval(3600)
        let settings = CookieSettings.default(content: "token", expires: expires)

        #expect(settings.content == "token")
        #expect(settings.expires == expires)
        #expect(settings.isSecure == CookieConfiguration.isSecure)
        #expect(settings.isHTTPOnly == CookieConfiguration.isHTTPOnly)
        #expect(settings.sameSite == CookieConfiguration.sameSitePolicy)
        #expect(settings.path == CookieConfiguration.defaultPath)
    }

    @Test("CookieSettings maxAge is calculated correctly")
    func maxAgeIsCalculatedCorrectly() {
        let now = Date()
        let futureDate = now.addingTimeInterval(1000) // 1000 seconds in future

        let settings = CookieSettings(
            content: "test",
            expires: futureDate
        )

        // maxAge should be approximately 1000 (allowing for small timing differences)
        let maxAge = settings.maxAge
        #expect(maxAge >= 999 && maxAge <= 1001)
    }

    @Test("CookieSettings maxAge is negative for past dates")
    func maxAgeIsNegativeForPastDates() {
        let pastDate = Date().addingTimeInterval(-1000) // 1000 seconds ago

        let settings = CookieSettings(
            content: "expired",
            expires: pastDate
        )

        // maxAge should be negative for past dates
        #expect(settings.maxAge < 0)
    }

    @Test("CookieSettings with empty content")
    func worksWithEmptyContent() {
        let expires = Date().addingTimeInterval(3600)
        let settings = CookieSettings(content: "", expires: expires)

        #expect(settings.content == "")
    }

    @Test("CookieSettings with long content")
    func worksWithLongContent() {
        let longContent = String(repeating: "a", count: 1000)
        let expires = Date().addingTimeInterval(3600)
        let settings = CookieSettings(content: longContent, expires: expires)

        #expect(settings.content.count == 1000)
    }

    @Test("CookieSettings with special characters in content")
    func worksWithSpecialCharacters() {
        let specialContent = "token=value; secure=true"
        let expires = Date().addingTimeInterval(3600)
        let settings = CookieSettings(content: specialContent, expires: expires)

        #expect(settings.content == specialContent)
    }

    @Test("CookieSettings maxAge updates with different expiry dates")
    func maxAgeUpdatesWithDifferentExpiryDates() {
        let content = "test"

        let nearFuture = Date().addingTimeInterval(100)
        let settings1 = CookieSettings(content: content, expires: nearFuture)

        let farFuture = Date().addingTimeInterval(10_000)
        let settings2 = CookieSettings(content: content, expires: farFuture)

        #expect(settings2.maxAge > settings1.maxAge)
    }

    @Test("CookieSettings can be created with all SameSite policies")
    func canBeCreatedWithAllSameSitePolicies() {
        let expires = Date().addingTimeInterval(3600)

        let strictSettings = CookieSettings(content: "test", expires: expires, sameSite: .strict)
        #expect(strictSettings.sameSite == .strict)

        let laxSettings = CookieSettings(content: "test", expires: expires, sameSite: .lax)
        #expect(laxSettings.sameSite == .lax)

        let noRestrictionSettings = CookieSettings(content: "test", expires: expires, sameSite: .noRestriction)
        #expect(noRestrictionSettings.sameSite == .noRestriction)
    }

    @Test("CookieSettings with custom path")
    func worksWithCustomPath() {
        let expires = Date().addingTimeInterval(3600)
        let settings = CookieSettings(
            content: "test",
            expires: expires,
            path: "/api/v1"
        )

        #expect(settings.path == "/api/v1")
    }

    @Test("CookieSettings isSecure can be overridden")
    func isSecureCanBeOverridden() {
        let expires = Date().addingTimeInterval(3600)

        let secureSettings = CookieSettings(content: "test", expires: expires, isSecure: true)
        #expect(secureSettings.isSecure == true)

        let insecureSettings = CookieSettings(content: "test", expires: expires, isSecure: false)
        #expect(insecureSettings.isSecure == false)
    }

    @Test("CookieSettings isHTTPOnly can be overridden")
    func isHTTPOnlyCanBeOverridden() {
        let expires = Date().addingTimeInterval(3600)

        let httpOnlySettings = CookieSettings(content: "test", expires: expires, isHTTPOnly: true)
        #expect(httpOnlySettings.isHTTPOnly == true)

        let notHttpOnlySettings = CookieSettings(content: "test", expires: expires, isHTTPOnly: false)
        #expect(notHttpOnlySettings.isHTTPOnly == false)
    }
}
