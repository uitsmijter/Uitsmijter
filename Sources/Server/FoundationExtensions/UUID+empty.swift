import Foundation

extension UUID {
    static var empty: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000000")! // swiftlint:disable:this force_unwrapping
    }
}
