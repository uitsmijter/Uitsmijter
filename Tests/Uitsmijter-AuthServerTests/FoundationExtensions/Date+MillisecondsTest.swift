import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@Suite("Date Milliseconds Extension Tests")
struct DateMillisecondsTest {

    // MARK: - millisecondsSinceNow Tests

    @Test("millisecondsSinceNow returns negative value for past dates")
    func millisecondsSinceNowPastDate() throws {
        let pastDate = Date(timeIntervalSinceNow: -5.0) // 5 seconds ago
        let milliseconds = pastDate.millisecondsSinceNow

        // Should be approximately -5000ms (allowing small timing variance)
        #expect(milliseconds < -4900)
        #expect(milliseconds > -5100)
    }

    @Test("millisecondsSinceNow returns positive value for future dates")
    func millisecondsSinceNowFutureDate() throws {
        let futureDate = Date(timeIntervalSinceNow: 5.0) // 5 seconds in future
        let milliseconds = futureDate.millisecondsSinceNow

        // Should be approximately 5000ms (allowing small timing variance)
        #expect(milliseconds > 4900)
        #expect(milliseconds < 5100)
    }

    @Test("millisecondsSinceNow returns approximately zero for current date")
    func millisecondsSinceNowCurrentDate() throws {
        let now = Date()
        let milliseconds = now.millisecondsSinceNow

        // Should be very close to 0 (within 10ms for test execution time)
        #expect(milliseconds >= -10)
        #expect(milliseconds <= 10)
    }

    @Test("millisecondsSinceNow with one second ago")
    func millisecondsSinceNowOneSecondAgo() throws {
        let oneSecondAgo = Date(timeIntervalSinceNow: -1.0)
        let milliseconds = oneSecondAgo.millisecondsSinceNow

        // Should be approximately -1000ms
        #expect(milliseconds < -990)
        #expect(milliseconds > -1010)
    }

    @Test("millisecondsSinceNow with one second in future")
    func millisecondsSinceNowOneSecondFuture() throws {
        let oneSecondFuture = Date(timeIntervalSinceNow: 1.0)
        let milliseconds = oneSecondFuture.millisecondsSinceNow

        // Should be approximately 1000ms
        #expect(milliseconds > 990)
        #expect(milliseconds < 1010)
    }

    @Test("millisecondsSinceNow with millisecond precision")
    func millisecondsSinceNowMillisecondPrecision() throws {
        let date = Date(timeIntervalSinceNow: -0.5) // 500ms ago
        let milliseconds = date.millisecondsSinceNow

        // Should be approximately -500ms
        #expect(milliseconds < -490)
        #expect(milliseconds > -510)
    }

    @Test("millisecondsSinceNow with very small time difference")
    func millisecondsSinceNowSmallDifference() throws {
        let date = Date(timeIntervalSinceNow: -0.001) // 1ms ago
        let milliseconds = date.millisecondsSinceNow

        // Should be approximately -1ms (within reasonable tolerance)
        #expect(milliseconds >= -10)
        #expect(milliseconds <= 10)
    }

    @Test("millisecondsSinceNow with large time difference")
    func millisecondsSinceNowLargeDifference() throws {
        let oneHourAgo = Date(timeIntervalSinceNow: -3600.0) // 1 hour ago
        let milliseconds = oneHourAgo.millisecondsSinceNow

        // Should be approximately -3,600,000ms
        let expected = -3_600_000
        #expect(milliseconds < expected + 100)
        #expect(milliseconds > expected - 100)
    }

    @Test("millisecondsSinceNow returns integer value")
    func millisecondsSinceNowReturnsInteger() throws {
        let date = Date(timeIntervalSinceNow: -2.7) // 2.7 seconds ago
        let milliseconds = date.millisecondsSinceNow

        // Should be rounded to integer (approximately -2700)
        #expect(milliseconds < -2690)
        #expect(milliseconds > -2710)
    }

    // MARK: - init(millisecondsSinceNow:) Tests

    @Test("Initialize date with positive milliseconds")
    func initWithPositiveMilliseconds() throws {
        let date = Date(millisecondsSinceNow: 5000) // 5 seconds in future

        // Verify it's approximately 5 seconds in the future
        let interval = date.timeIntervalSinceNow
        #expect(interval > 4.9)
        #expect(interval < 5.1)
    }

    @Test("Initialize date with negative milliseconds")
    func initWithNegativeMilliseconds() throws {
        let date = Date(millisecondsSinceNow: -5000) // 5 seconds ago

        // Verify it's approximately 5 seconds in the past
        let interval = date.timeIntervalSinceNow
        #expect(interval < -4.9)
        #expect(interval > -5.1)
    }

    @Test("Initialize date with zero milliseconds")
    func initWithZeroMilliseconds() throws {
        let date = Date(millisecondsSinceNow: 0)

        // Should be approximately now
        let interval = date.timeIntervalSinceNow
        #expect(interval >= -0.01)
        #expect(interval <= 0.01)
    }

    @Test("Initialize date with one second in milliseconds")
    func initWithOneSecond() throws {
        let date = Date(millisecondsSinceNow: 1000)

        // Verify it's approximately 1 second in the future
        let interval = date.timeIntervalSinceNow
        #expect(interval > 0.99)
        #expect(interval < 1.01)
    }

    @Test("Initialize date with one millisecond")
    func initWithOneMillisecond() throws {
        let date = Date(millisecondsSinceNow: 1)

        // Verify it's approximately 0.001 seconds in the future
        let interval = date.timeIntervalSinceNow
        #expect(interval >= 0.0)
        #expect(interval <= 0.01)
    }

    @Test("Initialize date with large millisecond value")
    func initWithLargeMilliseconds() throws {
        let oneHourMs = 3_600_000 // 1 hour in milliseconds
        let date = Date(millisecondsSinceNow: oneHourMs)

        // Verify it's approximately 1 hour in the future
        let interval = date.timeIntervalSinceNow
        #expect(interval > 3599.0)
        #expect(interval < 3601.0)
    }

    @Test("Initialize date with negative large millisecond value")
    func initWithNegativeLargeMilliseconds() throws {
        let oneHourMs = -3_600_000 // 1 hour ago in milliseconds
        let date = Date(millisecondsSinceNow: oneHourMs)

        // Verify it's approximately 1 hour in the past
        let interval = date.timeIntervalSinceNow
        #expect(interval < -3599.0)
        #expect(interval > -3601.0)
    }

    @Test("Initialize date with fractional second in milliseconds")
    func initWithFractionalSecond() throws {
        let date = Date(millisecondsSinceNow: 500) // 0.5 seconds

        // Verify it's approximately 0.5 seconds in the future
        let interval = date.timeIntervalSinceNow
        #expect(interval > 0.49)
        #expect(interval < 0.51)
    }

    // MARK: - Round-trip Tests

    @Test("Round-trip conversion preserves approximate time")
    func roundTripConversion() throws {
        let originalMs = 5000 // 5 seconds
        let date = Date(millisecondsSinceNow: originalMs)

        // Small delay to ensure time has passed
        Thread.sleep(forTimeInterval: 0.01)

        let resultMs = date.millisecondsSinceNow

        // Should be close to original value (slightly less due to elapsed time)
        #expect(resultMs < originalMs)
        #expect(resultMs > originalMs - 100) // Within 100ms tolerance
    }

    @Test("Round-trip with negative milliseconds")
    func roundTripNegativeMilliseconds() throws {
        let originalMs = -5000 // 5 seconds ago
        let date = Date(millisecondsSinceNow: originalMs)

        // Small delay to ensure time has passed
        Thread.sleep(forTimeInterval: 0.01)

        let resultMs = date.millisecondsSinceNow

        // Should be more negative due to elapsed time
        #expect(resultMs < originalMs - 5)
        #expect(resultMs > originalMs - 100)
    }

    @Test("Round-trip with zero milliseconds")
    func roundTripZeroMilliseconds() throws {
        let date = Date(millisecondsSinceNow: 0)

        // Immediate check (minimal elapsed time)
        let resultMs = date.millisecondsSinceNow

        // Should be very close to zero
        #expect(resultMs >= -50)
        #expect(resultMs <= 50)
    }

    // MARK: - Edge Cases

    @Test("Date created now has millisecondsSinceNow near zero")
    func dateNowHasZeroMilliseconds() throws {
        let now = Date()
        let milliseconds = now.millisecondsSinceNow

        // Should be very close to 0
        #expect(milliseconds >= -10)
        #expect(milliseconds <= 10)
    }

    @Test("Multiple dates created in sequence have increasing negative milliseconds")
    func sequentialDatesHaveIncreasingNegativeMilliseconds() throws {
        let date1 = Date()
        Thread.sleep(forTimeInterval: 0.05) // 50ms delay
        let date2 = Date()

        let ms1 = date1.millisecondsSinceNow
        let ms2 = date2.millisecondsSinceNow

        // date1 should be more negative (further in past)
        #expect(ms1 < ms2)
    }

    @Test("Initialize with very small milliseconds")
    func initWithVerySmallMilliseconds() throws {
        let date = Date(millisecondsSinceNow: 1)

        let interval = date.timeIntervalSinceNow
        #expect(interval >= 0.0)
        #expect(interval <= 0.01)
    }

    @Test("Initialize with very large milliseconds")
    func initWithVeryLargeMilliseconds() throws {
        let oneDayMs = 86_400_000 // 24 hours in milliseconds
        let date = Date(millisecondsSinceNow: oneDayMs)

        let interval = date.timeIntervalSinceNow
        #expect(interval > 86_399.0)
        #expect(interval < 86_401.0)
    }

    // MARK: - Practical Use Cases

    @Test("Calculate expiration time for JWT token")
    func jwtTokenExpiration() throws {
        // JWT typically expires in 2 hours (7200 seconds = 7,200,000 milliseconds)
        let expirationDate = Date(millisecondsSinceNow: 7_200_000)

        // Verify it's approximately 2 hours in the future
        let interval = expirationDate.timeIntervalSinceNow
        #expect(interval > 7199.0)
        #expect(interval < 7201.0)

        // Check milliseconds until expiration
        let msUntilExpiration = expirationDate.millisecondsSinceNow
        #expect(msUntilExpiration > 7_199_000)
        #expect(msUntilExpiration < 7_201_000)
    }

    @Test("Check if token is expired using milliseconds")
    func checkTokenExpired() throws {
        // Create expired token (1 second ago)
        let expiredToken = Date(millisecondsSinceNow: -1000)

        // Check if expired
        #expect(expiredToken.millisecondsSinceNow < 0)

        // Create valid token (1 hour in future)
        let validToken = Date(millisecondsSinceNow: 3_600_000)

        // Check if still valid
        #expect(validToken.millisecondsSinceNow > 0)
    }

    @Test("Calculate time remaining until expiration")
    func timeRemainingUntilExpiration() throws {
        // Token expires in 30 seconds
        let expirationDate = Date(millisecondsSinceNow: 30_000)

        let remaining = expirationDate.millisecondsSinceNow

        // Should be approximately 30,000ms
        #expect(remaining > 29_900)
        #expect(remaining < 30_100)

        // Convert to seconds
        let secondsRemaining = remaining / 1000
        #expect(secondsRemaining >= 29)
        #expect(secondsRemaining <= 31)
    }

    @Test("Compare two dates using milliseconds")
    func compareDatesUsingMilliseconds() throws {
        let date1 = Date(millisecondsSinceNow: -5000) // 5 seconds ago
        let date2 = Date(millisecondsSinceNow: -3000) // 3 seconds ago

        let ms1 = date1.millisecondsSinceNow
        let ms2 = date2.millisecondsSinceNow

        // date1 is older, so should be more negative
        #expect(ms1 < ms2)
    }

    @Test("Precision with fractional seconds")
    func precisionWithFractionalSeconds() throws {
        // 1.5 seconds = 1500 milliseconds
        let date = Date(millisecondsSinceNow: 1500)

        let interval = date.timeIntervalSinceNow
        #expect(interval > 1.49)
        #expect(interval < 1.51)
    }

    @Test("Date arithmetic with milliseconds")
    func dateArithmeticWithMilliseconds() throws {
        // Create a date 10 seconds in the future
        let futureDate = Date(millisecondsSinceNow: 10_000)

        // Add another 5 seconds (5000ms)
        let evenLaterDate = Date(
            timeInterval: 5.0,
            since: futureDate
        )

        // Should be approximately 15 seconds in the future
        let ms = evenLaterDate.millisecondsSinceNow
        #expect(ms > 14_900)
        #expect(ms < 15_100)
    }
}
