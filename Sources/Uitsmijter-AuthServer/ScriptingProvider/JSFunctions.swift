import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import JXKit

/// A delegation protocol to receive messages from javascript when a value is committed
protocol JSFunctionsDelegate {
    nonisolated func valueDidCommitted(data: [String?])
}

/// Functions that can be applied to the JavaScript context
///
/// The JavaScript language (_webkitgtk is used_) does not now a certain kind of functions that are implemented by
/// the runtime (Browser) typically. Common functions like `console.log` and `fetch` are expected by the provider
/// author to create a plugin. JSFunctions implements those functions and applied them to the `global-scope` of the
/// context.
///
/// - Attention: Do not attach JSFunctions on your own, let the `JavaScript` class do this always on a new created
///              context.
///
///
struct JSFunctions {
    /// The context to apply the functions to
    let ctx: JXContext

    /// A delegation protocol implementation to receive messages from the evaluated javascript context
    ///
    /// - Note: the delegate have to be set into the functions which is not how it should work, but necessary for
    ///         the usage with JXKit. Tracked here to be more swift like
    ///
    var delegate: JSFunctionsDelegate?

    /// Decoder to decode structs into json
    let encoder = JSONEncoder()

    /// Initialize a new JSFunction that applied to the javascript context
    ///
    /// - Attention: The delegate has to be set into the initializer. That is because the function-factory needs to have
    ///              a **local** value-copy, that is a _unswifty_ way how JXKit works. @see `commit`.
    ///
    /// - Parameters:
    ///   - ctx: The javascript context to where the functions applied to
    ///   - delegate: A delegate that receive messages from javascript
    ///
    @discardableResult
    init(bind ctx: JXContext, delegate: JSFunctionsDelegate) {
        self.ctx = ctx
        self.delegate = delegate

        ctx.global["say"] = say()
        ctx.global["console"]["log"] = say(.info)
        ctx.global["console"]["error"] = say(.error)
        ctx.global["fetch"] = fetch()
        ctx.global["commit"] = commit(to: delegate)
        ctx.global["md5"] = md5()
        ctx.global["sha256"] = sha256()
    }

    // MARK: - notifications back to the swift caller context

    /// Every script have to commit its value back into swift
    /// Committing is necessary in async functions, because the caller have to wait for the end of the script execution.
    ///
    /// - Important: Commit the state from javascript only once when all necessary information can be get without
    ///              asynchronous call. The state that is committed should be castable to the provider state protocol.
    ///
    /// - Parameter delegate: The delegate is necessary to pass into the function, that is special to JSKit
    /// - Returns: A function that can be called from within javascript
    ///
    func commit(to delegate: JSFunctionsDelegate?) -> JXValue {
        JXValue(newFunctionIn: ctx) { context, _, arguments in
            delegate?.valueDidCommitted(data: arguments.map({ try? $0.toJSON() }))
            return JXValue(nullIn: context)
        }
    }

    // MARK: - register functions

    /// Registers a new function wrapped in a JXValue that can be called from within the javascript context
    ///
    /// - Parameters:
    ///   - name: the name for the function that is available as function name in javascript
    ///   - fn: The JXValue wrapped swift function that can be called from javascript
    ///
    func registerFunction(name: String, fn: JXValue) {
        ctx.global[name] = fn
    }

}
