import Foundation
import Vapor
import Leaf

/// Renders a string if the given variable is not empty
struct IsNotEmptyThenTag: LeafTag {

    static let name = "isnotempty"

    /// main render func
    func render(_ ctx: LeafContext) throws -> LeafData {
        /// needs at least the root navigation id
        try ctx.requireParameterCount(2)

        let hasValue: Bool = ctx.parameters.first?.string?.count ?? 0 > 0

        return hasValue == true ? .string(ctx.parameters.last?.string) : ""
    }
}
