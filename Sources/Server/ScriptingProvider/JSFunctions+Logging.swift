import Foundation
import JXKit

extension JSFunctions {
    // MARK: - Logging functions

    /// Possible log levels for console.log and console error.
    enum LogLevels {
        case info
        case error
    }

    /// Console.log function implementation
    /// - See:
    ///     - console.log
    ///     - console.error
    ///     - say
    ///
    /// - Returns: a nil value
    ///
    func say(_ level: LogLevels? = .info) -> JXValue {
        JXValue(newFunctionIn: ctx) { context, _, arguments in
            let toSay = arguments.compactMap(\.stringValue)
            switch level {
            case .error:
                Log.error("|js|\(ctx.ident): \(toSay.joined(separator: " "))")
            default:
                Log.info("|js|\(ctx.ident): \(toSay.joined(separator: " "))")
            }
            return JXValue(nullIn: context)
        }
    }
}
