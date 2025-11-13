import Foundation
import JXKit
import Logger

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
        JXValue(newFunctionIn: ctx) { [logWriter] context, _, arguments in
            let toSay = arguments.compactMap { arg -> String? in
                // Convert all types to strings
                if let str = arg.stringValue {
                    return str
                } else if let num = arg.numberValue {
                    return String(describing: num)
                } else if arg.isBoolean {
                    return String(describing: arg.booleanValue)
                }
                return arg.stringValue  // Fallback for other types
            }
            let message = "|js|\(ctx.ident): \(toSay.joined(separator: " "))"

            // Use isolated logWriter if provided, otherwise use global Log
            if let logWriter {
                switch level {
                case .error:
                    logWriter.log(
                        level: .error,
                        message: .init(stringLiteral: message),
                        metadata: nil,
                        source: "JSFunctions",
                        file: #fileID,
                        function: #function,
                        line: #line
                    )
                default:
                    logWriter.log(
                        level: .info,
                        message: .init(stringLiteral: message),
                        metadata: nil,
                        source: "JSFunctions",
                        file: #fileID,
                        function: #function,
                        line: #line
                    )
                }
            } else {
                // Fallback to global Log singleton
                switch level {
                case .error:
                    Log.error(message)
                default:
                    Log.info(message)
                }
            }
            return JXValue(nullIn: context)
        }
    }
}
