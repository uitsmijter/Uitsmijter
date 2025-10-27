import Foundation

enum TestError: Error {
    case abort
    case fail(withError: String)
}
