import Foundation
import Vapor

/// Translation strings
struct TranslationProvider {
    /// All languages known in the system
    let translations: [String: Dictionary<String, AnyObject>]

    /// The default language if no other match
    static let defaultLanguage = "en_EN"

    init() {
        var translations: [String: Dictionary<String, AnyObject>] = [:]

        /// lock inside the translation folder for files
        let fileManager = FileManager.default
        do {
            // Get the directory contents urls (including subfolders urls)
            Log.info("Loading translation from \(resourcePath.appending("/Translations"))")

            let allFiles = try fileManager.contentsOfDirectory(atPath: resourcePath.appending("/Translations"))
            let langFiles = allFiles.filter { lang in
                URL(fileURLWithPath: resourcePath.appending("/Translations/\(lang)")).pathExtension == "json"
            }
            for filename in langFiles {
                let url = URL(fileURLWithPath: resourcePath.appending("/Translations/\(filename)"))
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

    /// Returns a dictionary with translations for one language
    public func getTranslation(for lang: String) -> Dictionary<String, AnyObject>? {
        translations[lang] ?? translations[TranslationProvider.defaultLanguage]
    }

    /// Lists all known languages
    public var knownLanguages: [String] {
        translations.compactMap({ (key: String, _: Any?) -> String in
            key
        })
    }

    /// returns a translated string for path for a language
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
