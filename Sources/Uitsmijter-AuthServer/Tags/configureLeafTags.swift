import Foundation
import Vapor
import Leaf

/// Configures and registers all custom Leaf template tags for the application.
///
/// This function registers custom tags that extend Leaf's templating capabilities with
/// additional functionality such as translations and conditional rendering.
///
/// - Parameter leaf: The Leaf configuration object from the Vapor application.
///
/// ## Registered Tags
/// - `#isnotempty()`: Conditionally renders content if a variable is not empty
/// - `#t()`: Provides internationalization and translation support
///
/// ## Usage
/// Call this function during application configuration, typically in `configure.swift`:
/// ```swift
/// configureLeafTags(app.leaf)
/// ```
func configureLeafTags(_ leaf: Application.Leaf) {
    leaf.tags[IsNotEmptyThenTag.name] = IsNotEmptyThenTag()
    leaf.tags[TranslationTag.name] = TranslationTag()
}
