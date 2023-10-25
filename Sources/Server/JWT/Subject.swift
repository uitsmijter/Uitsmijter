import Foundation
import JWT

protocol SubjectProtocol {

    /// The "sub" (subject) claim identifies the principal that is the
    /// subject of the JWT.
    var subject: SubjectClaim { get set }
}

struct Subject: SubjectProtocol, Decodable {
    var subject: SubjectClaim
}

extension SubjectProtocol {

    /// Creates multiple `SubjectProtocol`s from a StringArray if one or more of the values
    /// contains a {subject: ""} literal.
    ///
    /// - Parameter values: Array of `String` with possible subject values
    /// - Returns: Array of `SubjectProtocol`s
    ///
    static func decode(from values: [String]?) -> [SubjectProtocol] {
        // is subject given in fetchedValue
        let subjects: [SubjectProtocol]? = values?.compactMap { (element: String?) -> SubjectProtocol? in
            if let element, let data = element.data(using: .utf8) {
                if let result = try? JSONDecoder.main.decode(Subject.self, from: data) {
                    return result
                }
            }
            return nil
        }
        return subjects ?? []
    }
}
