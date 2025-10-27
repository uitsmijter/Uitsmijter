import Testing
@testable import Uitsmijter_AuthServer

@Suite(.serialized, .disabled("MainActor concurrency issues with EntityStorage access"))
struct EntityFileLoaderMonitoredTests {
    // Tests temporarily disabled due to Swift 6.2 MainActor concurrency issues
    // These tests access MainActor-isolated EntityStorage from nonisolated test functions
}
