import Foundation
import Vapor
import Leaf

/// A Leaf template tag for conditional rendering based on whether a variable is non-empty.
///
/// The `IsNotEmptyThenTag` provides conditional rendering functionality in Leaf templates using
/// the `#isnotempty()` syntax. It checks if the first parameter is a non-empty string and, if so,
/// renders the second parameter. This is useful for showing content only when a value exists.
///
/// ## Usage
/// ```leaf
/// #isnotempty(username, "Welcome back, " + username)
/// #isnotempty(errorMessage, "<div class='error'>" + errorMessage + "</div>")
/// ```
///
/// ## Parameters
/// - **First parameter**: The variable to check for emptiness
/// - **Second parameter**: The content to render if the first parameter is not empty
///
/// ## Behavior
/// - Returns the second parameter if the first parameter is a non-empty string
/// - Returns an empty string if the first parameter is empty, nil, or has zero length
///
/// ## Example
/// Given a template:
/// ```leaf
/// #isnotempty(user.name, "Hello, " + user.name + "!")
/// ```
/// - If `user.name` is `"Alice"`, renders: `"Hello, Alice!"`
/// - If `user.name` is empty or nil, renders: `""` (empty string)
struct IsNotEmptyThenTag: LeafTag {

    /// The tag name used in Leaf templates.
    static let name = "isnotempty"

    /// Renders the tag by conditionally returning content based on whether the first parameter is non-empty.
    ///
    /// This method checks if the first parameter contains a non-empty string. If it does, the second
    /// parameter is returned as the rendered content. Otherwise, an empty string is returned.
    ///
    /// - Parameter ctx: The Leaf context containing the tag parameters.
    /// - Returns: A `LeafData` containing the second parameter's string value if the first parameter
    ///           is non-empty, or an empty string otherwise.
    /// - Throws: An error if the required two parameters are not provided.
    ///
    /// ## Implementation Details
    /// - Requires exactly 2 parameters (enforced via `requireParameterCount(2)`)
    /// - The first parameter is evaluated: if its string length > 0, it's considered non-empty
    /// - Nil values or empty strings are treated as empty
    /// - The second parameter is returned unchanged if the condition is met
    func render(_ ctx: LeafContext) throws -> LeafData {
        // Ensure both required parameters are provided
        try ctx.requireParameterCount(2)

        let hasValue: Bool = ctx.parameters.first?.string?.count ?? 0 > 0

        return hasValue == true ? .string(ctx.parameters.last?.string) : ""
    }
}
