import Testing
@testable import Uitsmijter_AuthServer

@Suite("String Crypto Extension Tests")
struct StringCryptoTest {

    @Test("MD5 hash of empty string")
    func md5EmptyString() throws {
        let result = "".md5()
        #expect(result == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test("MD5 hash of simple string")
    func md5SimpleString() throws {
        let result = "hello".md5()
        #expect(result == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test("MD5 hash of string with numbers")
    func md5StringWithNumbers() throws {
        let result = "test123".md5()
        #expect(result == "cc03e747a6afbbcbf8be7668acfebee5")
    }

    @Test("MD5 hash of string with special characters")
    func md5StringWithSpecialChars() throws {
        let result = "hello@world!".md5()
        #expect(result == "854245bd59d2a3d09f4444e761e6cb5e")
    }

    @Test("MD5 hash of string with spaces")
    func md5StringWithSpaces() throws {
        let result = "hello world".md5()
        #expect(result == "5eb63bbbe01eeed093cb22bb8f5acdc3")
    }

    @Test("MD5 hash of unicode string")
    func md5UnicodeString() throws {
        let result = "hello 🌍".md5()
        #expect(result == "7d78df32c5b0adb3839b45615fb1486b")
    }

    @Test("MD5 hash of long string")
    func md5LongString() throws {
        let longString = String(repeating: "a", count: 1000)
        let result = longString.md5()
        #expect(result == "cabe45dcc9ae5b66ba86600cca6b8ba8")
    }

    @Test("SHA256 hash of empty string")
    func sha256EmptyString() throws {
        let result = "".sha256()
        #expect(result == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("SHA256 hash of simple string")
    func sha256SimpleString() throws {
        let result = "hello".sha256()
        #expect(result == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    @Test("SHA256 hash of string with numbers")
    func sha256StringWithNumbers() throws {
        let result = "test123".sha256()
        #expect(result == "ecd71870d1963316a97e3ac3408c9835ad8cf0f3c1bc703527c30265534f75ae")
    }

    @Test("SHA256 hash of string with special characters")
    func sha256StringWithSpecialChars() throws {
        let result = "hello@world!".sha256()
        #expect(result == "c76199722ea70e8518b2ee58aa1106b0f499ce416d4c664489e2c15a63dfdb33")
    }

    @Test("SHA256 hash of string with spaces")
    func sha256StringWithSpaces() throws {
        let result = "hello world".sha256()
        #expect(result == "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")
    }

    @Test("SHA256 hash of unicode string")
    func sha256UnicodeString() throws {
        let result = "hello 🌍".sha256()
        #expect(result == "92de6bbfa52e6cfa0f85916fd8176cb1644b95a4c0148cdda94745ba6c35e5eb")
    }

    @Test("SHA256 hash of long string")
    func sha256LongString() throws {
        let longString = String(repeating: "a", count: 1000)
        let result = longString.sha256()
        #expect(result == "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
    }

    @Test("MD5 and SHA256 produce different results")
    func hashesAreDifferent() throws {
        let input = "test"
        let md5Result = input.md5()
        let sha256Result = input.sha256()

        #expect(md5Result != sha256Result)
        #expect(md5Result.count == 32)  // MD5 is 128 bits = 32 hex chars
        #expect(sha256Result.count == 64)  // SHA256 is 256 bits = 64 hex chars
    }

    @Test("Same input produces same hash")
    func consistentHashing() throws {
        let input = "consistent"

        let md5First = input.md5()
        let md5Second = input.md5()
        #expect(md5First == md5Second)

        let sha256First = input.sha256()
        let sha256Second = input.sha256()
        #expect(sha256First == sha256Second)
    }

    @Test("Different inputs produce different hashes")
    func differentInputsDifferentHashes() throws {
        let input1 = "test1"
        let input2 = "test2"

        #expect(input1.md5() != input2.md5())
        #expect(input1.sha256() != input2.sha256())
    }

    @Test("Hash output is lowercase hexadecimal")
    func hashIsLowercaseHex() throws {
        let result = "test".md5()

        // Check all characters are valid lowercase hex
        for char in result {
            #expect("0123456789abcdef".contains(char))
        }
    }
}
