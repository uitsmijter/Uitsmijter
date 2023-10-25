import Foundation

extension JSONDecoder {
    static let main = JSONDecoder()

    static func configureMainDecoder(config: (_ decoder: JSONDecoder) -> Void) {
        config(main)
    }
}
