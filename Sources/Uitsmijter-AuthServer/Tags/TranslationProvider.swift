import Foundation
import Vapor
import Logger

/// Manages translation resources for internationalization support.
///
/// The `TranslationProvider` loads and manages translation files from the filesystem,
/// providing access to localized strings for multiple languages. Translation files are
/// stored as JSON files in the `Translations` directory, with each file named after its
/// language code (e.g., `en_EN.json`, `de_DE.json`).
///
/// ## Translation File Format
/// Translation files use a hierarchical JSON structure:
/// ```json
/// {
///   "login": {
///     "title": "Sign In",
///     "button": "Login"
///   },
///   "error": {
///     "invalid": {
///       "credentials": "Invalid username or password"
///     }
///   }
/// }
/// ```
///
/// ## Usage
/// ```swift
/// let provider = TranslationProvider(resourcePath: "./Resources")
/// if let text = provider.getString(forPath: "login.title", in: "en_EN") {
///     print(text) // "Sign In"
/// }
/// ```
struct TranslationProvider {
    /// A dictionary mapping language codes to their complete translation dictionaries.
    ///
    /// The key is the language code (e.g., "en_EN", "de_DE"), and the value is the
    /// hierarchical translation structure loaded from the corresponding JSON file.
    let translations: [String: Dictionary<String, AnyObject>]

    /// The default language code used when a requested language is not available.
    ///
    /// Defaults to `"en_EN"` (English).
    static let defaultLanguage = "en_EN"

    /// Initializes the translation provider by loading all translation files from the specified directory.
    ///
    /// This initializer scans the `Translations` subdirectory within the resource path for JSON files,
    /// loading each file and associating it with its language code (determined by the filename).
    ///
    /// - Parameter resPath: The base path to the resources directory containing the `Translations` folder.
    ///                      Defaults to the current directory (`"./"`).
    ///
    /// ## File Discovery
    /// The initializer:
    /// 1. Looks for all files in `{resPath}/Translations/`
    /// 2. Filters for files with `.json` extension
    /// 3. Uses the filename (without extension) as the language code
    /// 4. Parses each JSON file and stores it in the translations dictionary
    ///
    /// ## Error Handling
    /// If the translations directory cannot be read or a JSON file is malformed, an error is logged
    /// and that particular translation file is skipped. The provider will still initialize with any
    /// successfully loaded translations.
    init(resourcePath resPath: String = "./") {
        var translations: [String: Dictionary<String, AnyObject>] = [:]

        // Scan the translations folder for JSON language files
        let fileManager = FileManager.default
        do {
            // Get the directory contents urls (including subfolders urls)
            Log.info("Loading translation from \(resPath.appending("/Translations"))")

            let allFiles = try fileManager.contentsOfDirectory(atPath: resPath.appending("/Translations"))
            let langFiles = allFiles.filter { lang in
                URL(fileURLWithPath: resPath.appending("/Translations/\(lang)")).pathExtension == "json"
            }
            for filename in langFiles {
                let url = URL(fileURLWithPath: resPath.appending("/Translations/\(filename)"))
                let lang = url.deletingPathExtension().lastPathComponent
                let data = try Data(contentsOf: url)
                let object = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                translations[lang] = object as AnyObject as? [String: AnyObject]
            }
        } catch {
            Log.error("Can not read localisation directory: \(error.localizedDescription)")
        }
        self.translations = translations
    }

    /// Retrieves the complete translation dictionary for a specific language.
    ///
    /// If the requested language is not available, this method automatically falls back
    /// to the default language translation.
    ///
    /// - Parameter lang: The language code to retrieve translations for (e.g., "en_EN", "de_DE").
    /// - Returns: A dictionary containing all translations for the requested language, or the default
    ///           language if the requested language is not found. Returns `nil` if neither the requested
    ///           nor default language is available.
    ///
    /// ## Example
    /// ```swift
    /// if let translations = provider.getTranslation(for: "de_DE") {
    ///     // Work with German translations
    /// }
    /// ```
    func getTranslation(for lang: String) -> Dictionary<String, AnyObject>? {
        translations[lang] ?? translations[TranslationProvider.defaultLanguage]
    }

    /// Returns an array of all available language codes loaded by the provider.
    ///
    /// This property provides a list of all successfully loaded translation files,
    /// represented by their language codes.
    ///
    /// - Returns: An array of language code strings (e.g., `["en_EN", "de_DE", "fr_FR"]`).
    ///
    /// ## Usage
    /// ```swift
    /// let availableLanguages = provider.knownLanguages
    /// print("Supported languages: \(availableLanguages.joined(separator: ", "))")
    /// ```
    var knownLanguages: [String] {
        translations.compactMap({ (key: String, _: Any?) -> String in
            key
        })
    }

    /// Retrieves a translated string for a specific key path in the specified language.
    ///
    /// This method navigates through the hierarchical translation structure using a dot-separated
    /// path to locate the requested translation string. It traverses nested dictionaries until
    /// it reaches the final key and returns the associated string value.
    ///
    /// - Parameters:
    ///   - path: A dot-separated key path to the translation string (e.g., "login.title",
    ///           "error.invalid.credentials").
    ///   - lang: The language code for the desired translation (e.g., "en_EN", "de_DE").
    /// - Returns: The translated string if found, or `nil` if the path doesn't exist, the language
    ///           is not available, or the value at the path is not a string.
    ///
    /// ## Path Navigation
    /// The method splits the path by dots and navigates through nested dictionaries:
    /// - Path `"login.title"` → Accesses `translations["login"]["title"]`
    /// - Path `"error.invalid.credentials"` → Accesses `translations["error"]["invalid"]["credentials"]`
    ///
    /// ## Error Handling
    /// The method returns `nil` and logs an error if:
    /// - The requested language is not available
    /// - The path is empty
    /// - Any intermediate path component doesn't exist or is not a dictionary
    /// - The final value is not a string
    ///
    /// ## Example
    /// ```swift
    /// // Given a translation file en_EN.json:
    /// // { "login": { "title": "Sign In" } }
    ///
    /// if let title = provider.getString(forPath: "login.title", in: "en_EN") {
    ///     print(title) // "Sign In"
    /// }
    /// ```
    func getString(forPath path: String, in lang: String) -> String? {
        var paths = path.split(separator: ".")
        guard let trans = getTranslation(for: lang) else {
            Log.error("Can not get language \(lang)")
            return nil
        }

        var cur: [String: AnyObject?]
        guard let last = paths.popLast()?.description else {
            Log.error("No element is given in \(path) for language \(lang)")
            return nil
        }

        cur = trans as [String: AnyObject?]
        for path in paths {
            if let translation = cur[path.description] {
                guard let _cur = translation as? [String: AnyObject?] else {
                    Log.error("Translation is not an Object for path \(path.description) in language \(lang)")
                    return nil
                }
                cur = _cur
            } else {
                Log.error("There is no path \(path.description) in the translation for language \(lang)")
                cur = [:]
            }
        }
        return cur[last] as? String
    }
}
