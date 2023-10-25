import Foundation

extension String {
    private static let slugSafeCharacters = CharacterSet(
            charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-"
    )

    /// Returns a URl-Safe Slug of that string
    var slug: String? {
        get {
            if let data = data(using: .ascii, allowLossyConversion: true) {
                if let str = String(data: data, encoding: .ascii) {
                    let urlComponents = str.lowercased().components(separatedBy: String.slugSafeCharacters.inverted)
                    // swiftlint:disable closure_end_indentation
                    return urlComponents.filter { component in
                                component != ""
                            }
                            .joined(separator: "-")
                    // swiftlint:enable closure_end_indentation
                }
            }
            return nil
        }
    }
}
