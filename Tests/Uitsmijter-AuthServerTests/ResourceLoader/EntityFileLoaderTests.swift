import Testing
@testable import Uitsmijter_AuthServer
@testable import Logger

@Suite(.disabled("MainActor concurrency issues with EntityStorage access"))
struct EntityFileLoaderTests {
    // Tests temporarily disabled due to Swift 6.2 MainActor concurrency issues
    // These tests access MainActor-isolated EntityStorage from nonisolated test functions
}
