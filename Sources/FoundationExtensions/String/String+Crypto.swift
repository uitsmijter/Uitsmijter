import Foundation
import CryptoSwift

public extension String {
    /// Returns the MD5 hash of the string
    func md5() -> String {
        Data(self.utf8).md5().toHexString()
    }

    /// Returns the SHA256 hash of the string
    func sha256() -> String {
        Data(self.utf8).sha256().toHexString()
    }
}
