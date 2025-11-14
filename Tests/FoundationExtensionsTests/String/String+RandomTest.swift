import Foundation
@testable import FoundationExtensions
import Testing

@Suite("String Random Extension Tests")
// swiftlint:disable type_body_length
struct StringRandomTest {

    // MARK: - RandomCharacterSet.aZ09 Tests

    @Test("aZ09 character set contains lowercase letters")
    func aZ09ContainsLowercase() {
        let charset = String.RandomCharacterSet.aZ09
        #expect(charset.value.contains("a"))
        #expect(charset.value.contains("z"))
        #expect(charset.value.contains("m"))
    }

    @Test("aZ09 character set contains uppercase letters")
    func aZ09ContainsUppercase() {
        let charset = String.RandomCharacterSet.aZ09
        #expect(charset.value.contains("A"))
        #expect(charset.value.contains("Z"))
        #expect(charset.value.contains("M"))
    }

    @Test("aZ09 character set contains digits")
    func aZ09ContainsDigits() {
        let charset = String.RandomCharacterSet.aZ09
        #expect(charset.value.contains("0"))
        #expect(charset.value.contains("9"))
        #expect(charset.value.contains("5"))
    }

    @Test("aZ09 character set has correct length")
    func aZ09CorrectLength() {
        let charset = String.RandomCharacterSet.aZ09
        // 26 lowercase + 26 uppercase + 10 digits = 62
        #expect(charset.value.count == 62)
    }

    @Test("aZ09 character set does not contain special characters")
    func aZ09NoSpecialChars() {
        let charset = String.RandomCharacterSet.aZ09
        #expect(!charset.value.contains("-"))
        #expect(!charset.value.contains("_"))
        #expect(!charset.value.contains("."))
        #expect(!charset.value.contains("~"))
        #expect(!charset.value.contains(" "))
    }

    // MARK: - RandomCharacterSet.codeVerifier Tests

    @Test("codeVerifier character set contains alphanumeric characters")
    func codeVerifierContainsAlphanumeric() {
        let charset = String.RandomCharacterSet.codeVerifier
        #expect(charset.value.contains("a"))
        #expect(charset.value.contains("Z"))
        #expect(charset.value.contains("0"))
        #expect(charset.value.contains("9"))
    }

    @Test("codeVerifier character set contains PKCE special characters")
    func codeVerifierContainsPKCEChars() {
        let charset = String.RandomCharacterSet.codeVerifier
        #expect(charset.value.contains("-"))
        #expect(charset.value.contains("."))
        #expect(charset.value.contains("_"))
        #expect(charset.value.contains("~"))
    }

    @Test("codeVerifier character set has correct length")
    func codeVerifierCorrectLength() {
        let charset = String.RandomCharacterSet.codeVerifier
        // 26 lowercase + 26 uppercase + 10 digits + 4 special chars = 66
        #expect(charset.value.count == 66)
    }

    @Test("codeVerifier character set complies with RFC 7636")
    func codeVerifierRFC7636Compliance() {
        let charset = String.RandomCharacterSet.codeVerifier
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"

        // Verify all characters in charset are allowed
        for char in charset.value {
            #expect(allowedChars.contains(char))
        }
    }

    // MARK: - RandomCharacterSet.custom Tests

    @Test("custom character set with simple string")
    func customSimpleString() {
        let charset = String.RandomCharacterSet.custom("abc123")
        #expect(charset.value == "abc123")
    }

    @Test("custom character set with special characters")
    func customWithSpecialChars() {
        let charset = String.RandomCharacterSet.custom("!@#$%^&*()")
        #expect(charset.value == "!@#$%^&*()")
    }

    @Test("custom character set with empty string")
    func customEmptyString() {
        let charset = String.RandomCharacterSet.custom("")
        #expect(charset.value == "")
    }

    @Test("custom character set with single character")
    func customSingleChar() {
        let charset = String.RandomCharacterSet.custom("X")
        #expect(charset.value == "X")
    }

    @Test("custom character set with unicode")
    func customWithUnicode() {
        let charset = String.RandomCharacterSet.custom("αβγδε")
        #expect(charset.value == "αβγδε")
    }

    // MARK: - String.random(length:of:) Tests

    @Test("random generates string of correct length")
    func randomCorrectLength() {
        let random = String.random(length: 10)
        #expect(random.count == 10)
    }

    @Test("random generates different strings on multiple calls")
    func randomGeneratesDifferentStrings() {
        let random1 = String.random(length: 20)
        let random2 = String.random(length: 20)

        // Extremely unlikely to be the same (1 in 62^20)
        #expect(random1 != random2)
    }

    @Test("random with zero length returns empty string")
    func randomZeroLength() {
        let random = String.random(length: 0)
        #expect(random.isEmpty)
        #expect(random.isEmpty)
    }

    @Test("random with length 1 returns single character")
    func randomLengthOne() {
        let random = String.random(length: 1)
        #expect(random.count == 1)
    }

    @Test("random with large length generates correct size")
    func randomLargeLength() {
        let random = String.random(length: 1000)
        #expect(random.count == 1000)
    }

    @Test("random with aZ09 contains only alphanumeric")
    func randomAZ09OnlyAlphanumeric() {
        let random = String.random(length: 100, of: .aZ09)

        for char in random {
            let isLowercase = char >= "a" && char <= "z"
            let isUppercase = char >= "A" && char <= "Z"
            let isDigit = char >= "0" && char <= "9"

            #expect(isLowercase || isUppercase || isDigit)
        }
    }

    @Test("random with codeVerifier contains valid PKCE characters")
    func randomCodeVerifierValidChars() {
        let random = String.random(length: 128, of: .codeVerifier)
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"

        for char in random {
            #expect(allowedChars.contains(char))
        }
    }

    @Test("random with custom character set uses only those characters")
    func randomCustomCharsOnly() {
        let customSet = String.RandomCharacterSet.custom("XYZ")
        let random = String.random(length: 50, of: customSet)

        for char in random {
            #expect(char == "X" || char == "Y" || char == "Z")
        }
    }

    @Test("random with single character custom set repeats that character")
    func randomSingleCharCustomSet() {
        let customSet = String.RandomCharacterSet.custom("A")
        let random = String.random(length: 10, of: customSet)

        #expect(random == "AAAAAAAAAA")
    }

    @Test("random distribution is reasonably random")
    func randomReasonableDistribution() {
        // Generate multiple random strings and check that they use varied characters
        let charset = String.RandomCharacterSet.custom("01")
        var zeroCount = 0
        var oneCount = 0

        // Generate a large sample
        let sample = String.random(length: 1000, of: charset)

        for char in sample {
            if char == "0" {
                zeroCount += 1
            } else if char == "1" {
                oneCount += 1
            }
        }

        // With 1000 characters, expect roughly 500 of each (allow 200-800 range)
        #expect(zeroCount > 200)
        #expect(zeroCount < 800)
        #expect(oneCount > 200)
        #expect(oneCount < 800)
    }

    // MARK: - Practical Use Cases

    @Test("generate OAuth PKCE code verifier")
    func generatePKCECodeVerifier() {
        // RFC 7636 specifies code verifier should be 43-128 characters
        let codeVerifier = String.random(length: 128, of: .codeVerifier)

        #expect(codeVerifier.count == 128)

        // Verify only allowed characters
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        for char in codeVerifier {
            #expect(allowedChars.contains(char))
        }
    }

    @Test("generate session ID")
    func generateSessionID() {
        let sessionID = String.random(length: 32, of: .aZ09)

        #expect(sessionID.count == 32)

        // Should be alphanumeric only
        for char in sessionID {
            let isValid = (char >= "a" && char <= "z") ||
                (char >= "A" && char <= "Z") ||
                (char >= "0" && char <= "9")
            #expect(isValid)
        }
    }

    @Test("generate random password with custom character set")
    func generateRandomPassword() {
        let passwordChars = String.RandomCharacterSet.custom(
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        )
        let password = String.random(length: 16, of: passwordChars)

        #expect(password.count == 16)
    }

    @Test("generate API key")
    func generateAPIKey() {
        let apiKey = String.random(length: 64, of: .aZ09)

        #expect(apiKey.count == 64)

        // Verify uniqueness by generating multiple
        let apiKey2 = String.random(length: 64, of: .aZ09)
        #expect(apiKey != apiKey2)
    }

    @Test("generate short token")
    func generateShortToken() {
        let token = String.random(length: 6, of: .aZ09)

        #expect(token.count == 6)

        // All characters should be alphanumeric
        let alphanumeric = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for char in token {
            #expect(alphanumeric.contains(char))
        }
    }

    // MARK: - Edge Cases

    @Test("random with very large length")
    func randomVeryLargeLength() {
        let random = String.random(length: 10_000)
        #expect(random.count == 10_000)
    }

    @Test("multiple consecutive calls produce different results")
    func multipleCallsDifferentResults() {
        var results = Set<String>()

        for _ in 0..<100 {
            let random = String.random(length: 10, of: .aZ09)
            results.insert(random)
        }

        // Should have close to 100 unique results (allowing for tiny collision chance)
        #expect(results.count > 95)
    }

    @Test("default parameter uses aZ09")
    func defaultParameterUsesAZ09() {
        let random = String.random(length: 50)

        // Should only contain aZ09 characters
        let alphanumeric = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for char in random {
            #expect(alphanumeric.contains(char))
        }
    }

    @Test("custom set with duplicate characters still works")
    func customSetWithDuplicates() {
        let customSet = String.RandomCharacterSet.custom("AABBCC")
        let random = String.random(length: 20, of: customSet)

        #expect(random.count == 20)

        // All characters should be A, B, or C
        for char in random {
            #expect(char == "A" || char == "B" || char == "C")
        }
    }

    @Test("random with spaces in custom set")
    func customSetWithSpaces() {
        let customSet = String.RandomCharacterSet.custom("A B C")
        let random = String.random(length: 30, of: customSet)

        #expect(random.count == 30)

        // Can contain A, B, C, or space
        for char in random {
            #expect(char == "A" || char == "B" || char == "C" || char == " ")
        }
    }

    @Test("character set equality")
    func characterSetEquality() {
        let set1 = String.RandomCharacterSet.custom("ABC")
        let set2 = String.RandomCharacterSet.custom("ABC")

        #expect(set1.value == set2.value)
    }

    @Test("aZ09 is consistent across calls")
    func aZ09ConsistentAcrossCalls() {
        let set1 = String.RandomCharacterSet.aZ09
        let set2 = String.RandomCharacterSet.aZ09

        #expect(set1.value == set2.value)
    }

    @Test("codeVerifier is consistent across calls")
    func codeVerifierConsistentAcrossCalls() {
        let set1 = String.RandomCharacterSet.codeVerifier
        let set2 = String.RandomCharacterSet.codeVerifier

        #expect(set1.value == set2.value)
    }
}
// swiftlint:enable type_body_length
