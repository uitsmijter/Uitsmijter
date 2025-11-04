import Foundation
import JXKit

/// Extents the JXKit's JXContent to get out a readable name for the context
///
extension JXContext {

    /// The identifier of the context
    var ident: String {
        get {
            context.debugDescription
        }
    }

}
