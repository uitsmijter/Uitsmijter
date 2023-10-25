import Foundation

/// Extends `Date` with milliseconds functions
///
extension Date {

    /// The milliseconds between the `Date` and now
    var millisecondsSinceNow: Int {
        Int((timeIntervalSinceNow * 1000.0).rounded())
    }

    /// initialize a new `Date` with milliseconds since now
    ///
    /// - Parameter ms: Milliseconds since now
    init(millisecondsSinceNow ms: Int) {
        self = Date(timeIntervalSinceNow: TimeInterval(ms) / 1000)
    }
}
