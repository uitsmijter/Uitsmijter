import Vapor
import Leaf

struct TranslationTag: LeafTag {

    static let name = "t"
    static let provider = TranslationProvider()

    func render(_ ctx: LeafContext) throws -> LeafData {
        // get language from session
        let usersLanguage: String = getUserLanguage(from: ctx)

        // get token
        let parameterStrings: [String] = ctx.parameters.compactMap { parameter in
            parameter.string
        }
        let fullParameter = parameterStrings.joined(separator: ".")

        let result = getTranslation(for: fullParameter, in: usersLanguage)

        Log.debug("Translate: \(fullParameter) -> \(result)")
        return .string(result)

    }

    /// Retruns a translation for a tag, or the default translation, or the tag
    ///
    /// - Parameters:
    ///   - path: The full tag
    ///   - language: the requested language
    /// - Returns: a translated string or if there isn't one the tag.
    private func getTranslation(for path: String, in language: String) -> String {
        TranslationTag.provider.getString(
                forPath: path,
                in: language
        )
                ?? TranslationTag.provider.getString(
                forPath: path,
                in: TranslationProvider.defaultLanguage
        )
                ?? "\(path)"
    }

    private func getUserLanguage(from context: LeafContext) -> String {
        let languageFromHeader: String? = try? context.request?.headers["Accept-Language"]
                .first?
                .groups(regex: "[a-z]{2}-[A-Z]{2}")
                .first?
                .replacingOccurrences(of: "-", with: "_")
        guard let languageFromHeader else {
            return TranslationProvider.defaultLanguage
        }
        return languageFromHeader
    }
}
