import Foundation
import JXKit

extension JSFunctions {
    // MARK: - Hashing functions

    /// md5 function
    ///
    /// - Returns: a string with the md5 sum of the input
    ///
    func md5() -> JXValue {
        JXValue(newFunctionIn: ctx) { context, _, arguments in
            let value = arguments.first?.stringValue
            guard let md5 = value?.md5() else {
                return JXValue(nullIn: context)
            }

            return JXValue(string: md5, in: context)
        }
    }

    /// sha256 function
    ///
    /// - Returns: a string with the md5 sum of the input
    ///
    func sha256() -> JXValue {
        JXValue(newFunctionIn: ctx) { context, _, arguments in
            let value = arguments.first?.stringValue
            guard let sha256 = value?.sha256() else {
                return JXValue(nullIn: context)
            }

            return JXValue(string: sha256, in: context)
        }
    }
}
