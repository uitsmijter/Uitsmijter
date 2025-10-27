import Vapor
import Leaf
import Logger

/// A Leaf template tag for translating text based on user language preferences.
///
/// The `TranslationTag` provides internationalization support in Leaf templates using the `#t()` syntax.
/// It automatically detects the user's language from the `Accept-Language` HTTP header and retrieves
/// the appropriate translation from the translation provider.
///
/// ## Usage
/// ```leaf
/// #t("login.title")
/// #t("error.invalid.credentials")
/// ```
///
/// The tag falls back to the default language if a translation is not available in the requested language,
/// and ultimately returns the translation key itself if no translation is found.
struct TranslationTag: LeafTag {

    /// The tag name used in Leaf templates.
    static let name = "t"

    /// The translation provider that manages all translation resources for this tag instance.
    ///
    /// This provider is initialized with the application's resource path when the tag
    /// is registered, ensuring translations are loaded from the correct directory.
    let provider: TranslationProvider

    /// Renders the translation tag by looking up the appropriate translation for the user's language.
    ///
    /// This method extracts the user's language preference from the request headers, constructs the
    /// translation key from the tag parameters, and retrieves the corresponding translation.
    ///
    /// - Parameter ctx: The Leaf context containing request information and tag parameters.
    /// - Returns: A `LeafData` string containing the translated text.
    /// - Throws: An error if the rendering process fails.
    ///
    /// ## Translation Key Construction
    /// Multiple parameters are joined with dots to form a hierarchical key:
    /// - `#t("login", "title")` becomes `"login.title"`
    /// - `#t("error", "validation", "email")` becomes `"error.validation.email"`
    func render(_ ctx: LeafContext) throws -> LeafData {
        // Extract the user's preferred language from the request context
        let usersLanguage: String = getUserLanguage(from: ctx)

        // Construct the translation key from tag parameters
        let parameterStrings: [String] = ctx.parameters.compactMap { parameter in
            parameter.string
        }
        let fullParameter = parameterStrings.joined(separator: ".")

        let result = getTranslation(for: fullParameter, in: usersLanguage)

        Log.debug("Translate: \(fullParameter) -> \(result)")
        return .string(result)

    }

    /// Initializes a new translation tag with the specified resource path.
    ///
    /// - Parameter resourcePath: The base path to the resources directory containing translations.
    ///                          Defaults to the global `resourcePath` variable set during app configuration.
    init(resourcePath resPath: String? = nil) {
        let path = resPath ?? MainActor.assumeIsolated { resourcePath }
        self.provider = TranslationProvider(resourcePath: path)
    }

    /// Retrieves a translation for the specified key with fallback mechanisms.
    ///
    /// This method implements a three-tier fallback strategy:
    /// 1. Attempt to get the translation in the requested language
    /// 2. Fall back to the default language if not found
    /// 3. Return the translation key itself if no translation exists
    ///
    /// - Parameters:
    ///   - path: The translation key (e.g., "login.title" or "error.invalid.credentials").
    ///   - language: The requested language code in the format "xx_YY" (e.g., "en_US", "de_DE").
    /// - Returns: The translated string, the default language translation, or the original key if no translation is available.
    ///
    /// - SeeAlso: ``TranslationProvider`` for the translation provider implementation
    private func getTranslation(for path: String, in language: String) -> String {
        provider.getString(
            forPath: path,
            in: language
        )
        ?? provider.getString(
            forPath: path,
            in: TranslationProvider.defaultLanguage
        )
        ?? "\(path)"
    }

    /// Extracts the user's preferred language from the Leaf context.
    ///
    /// This method parses the `Accept-Language` HTTP header to determine the user's language preference.
    /// The language code is expected to be in the format "xx-YY" (e.g., "en-US", "de-DE") and is converted
    /// to the underscore format "xx_YY" used by the translation provider.
    ///
    /// - Parameter context: The Leaf context containing the HTTP request information.
    /// - Returns: The user's language code in "xx_YY" format, or the default language if the header
    ///           is missing or cannot be parsed.
    ///
    /// ## Header Parsing
    /// The method uses a regular expression `[a-z]{2}-[A-Z]{2}` to extract the language code from
    /// the Accept-Language header and converts hyphens to underscores for consistency with the
    /// translation provider's naming convention.
    ///
    /// ## Example
    /// - Header: `"Accept-Language: en-US,en;q=0.9"` → Returns: `"en_US"`
    /// - Header: `"Accept-Language: de-DE"` → Returns: `"de_DE"`
    /// - Missing header → Returns: Default language (e.g., `"en_US"`)
    private func getUserLanguage(from context: LeafContext) -> String {
        let languageFromHeader: String? = try? context.request?.headers["Accept-Language"]
            .first?
            .groups(regex: "[a-z]{2}-[A-Z]{2}")
            .first?
            .replacingOccurrences(of: "-", with: "_")

        guard let languageFromHeader else {
            Log.debug("Translate: Returning default language \(TranslationProvider.defaultLanguage)")
            return TranslationProvider.defaultLanguage
        }

        Log.debug("Translate: Returning user language from header \(languageFromHeader)")
        return languageFromHeader
    }
}
