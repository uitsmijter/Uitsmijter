import Foundation
import Vapor
import Leaf

/// A Leaf template tag to join an string-array into a string
///
struct JoinedWithTag: LeafTag {

    /// The tag name used in Leaf templates.
    static let name = "join"

    func render(_ ctx: LeafContext) throws -> LeafData {
        // Ensure both required parameters are provided
        try ctx.requireParameterCount(2)

        let joiner = ctx.parameters[0].string ?? ","
        let stringArray: [String]? = ctx.parameters[1].array?.compactMap(\.string)

        return .string( stringArray?.joined(separator: joiner) )
    }
}
