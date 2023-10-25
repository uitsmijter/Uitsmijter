import Foundation

extension JSONEncoder {
    static let main = JSONEncoder()

    static func configureMainEncoder(config: (_ encoder: JSONEncoder) -> Void) {
        config(main)
    }
}
