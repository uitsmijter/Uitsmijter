import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

@Suite("Code Tests")
@MainActor
struct CodeTests {

    @Test("Empty init") func emptyInit() {
        let code = Code()
        #expect(code.value.count == Constants.TOKEN.LENGTH)
        #expect(code.codeChallengeMethod == nil)
        #expect(code.codeChallenge == nil)
    }

    @Test("Empty init different values") func emptyInitDifferentValues() {
        let code1 = Code()
        let code2 = Code()
        #expect(code1.value != code2.value)
        #expect(!(code1 == code2))
    }

    @Test("Value init") func valueInit() {
        let code = Code(value: "abcdef")
        #expect(code.value.count == 6)
        #expect(code.codeChallengeMethod == nil)
        #expect(code.codeChallenge == nil)
    }

    @Test("Value init same value") func valueInitSameValue() {
        let code1 = Code(value: "abcdef")
        let code2 = Code(value: "abcdef")
        #expect(code1 == code2)
    }

    @Test("Challenge init") func challengeInit() {
        let code = Code(codeChallengeMethod: .plain, codeChallenge: "abcdef")
        #expect(code.value.count == Constants.TOKEN.LENGTH)
        #expect(code.codeChallengeMethod == .plain)
        #expect(code.codeChallenge == "abcdef")
    }

    @Test("Challenge equality") func challengeEquality() {
        var code1 = Code(value: "A")
        code1.codeChallengeMethod = .plain
        code1.codeChallenge = "abcdef"

        var code2 = Code(value: "A")
        code2.codeChallengeMethod = .plain
        code2.codeChallenge = "abcdef"

        var code3 = Code(value: "B")
        code3.codeChallengeMethod = .plain
        code3.codeChallenge = "123456"

        #expect(code1 == code2)
        #expect(!(code1 == code3))
    }

    @Test("Challenge equality auto values") func challengeEqualityAutoValues() {
        let code1 = Code(codeChallengeMethod: .plain, codeChallenge: "abcdef")
        let code2 = Code(codeChallengeMethod: .plain, codeChallenge: "abcdef")
        let code3 = Code(codeChallengeMethod: .plain, codeChallenge: "123456")
        // because the value is different
        #expect(!(code1 == code2))
        #expect(!(code1 == code3))
    }

}
