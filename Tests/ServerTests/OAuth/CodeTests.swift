import Foundation
import XCTVapor
@testable import Server

final class CodeTests: XCTestCase {

    func testEmptyInit() {
        let code = Code()
        XCTAssertEqual(code.value.count, Constants.TOKEN.LENGTH)
        XCTAssertNil(code.codeChallengeMethod)
        XCTAssertNil(code.codeChallenge)
    }

    func testEmptyInitDifferentValues() {
        let code1 = Code()
        let code2 = Code()
        XCTAssertNotEqual(code1.value, code2.value)
        XCTAssertFalse(code1 == code2)
    }

    func testValueInit() {
        let code = Code(value: "abcdef")
        XCTAssertEqual(code.value.count, 6)
        XCTAssertNil(code.codeChallengeMethod)
        XCTAssertNil(code.codeChallenge)
    }

    func testValueInitSameValue() {
        let code1 = Code(value: "abcdef")
        let code2 = Code(value: "abcdef")
        XCTAssertTrue(code1 == code2)
    }

    func testChallengeInit() {
        let code = Code(codeChallengeMethod: .plain, codeChallenge: "abcdef")
        XCTAssertEqual(code.value.count, Constants.TOKEN.LENGTH)
        XCTAssertEqual(code.codeChallengeMethod, .plain)
        XCTAssertEqual(code.codeChallenge, "abcdef")
    }

    func testChallengeEquality() {
        var code1 = Code(value: "A")
        code1.codeChallengeMethod = .plain
        code1.codeChallenge = "abcdef"

        var code2 = Code(value: "A")
        code2.codeChallengeMethod = .plain
        code2.codeChallenge = "abcdef"

        var code3 = Code(value: "B")
        code3.codeChallengeMethod = .plain
        code3.codeChallenge = "123456"

        XCTAssertTrue(code1 == code2)
        XCTAssertFalse(code1 == code3)
    }

    func testChallengeEqualityAutoValues() {
        let code1 = Code(codeChallengeMethod: .plain, codeChallenge: "abcdef")
        let code2 = Code(codeChallengeMethod: .plain, codeChallenge: "abcdef")
        let code3 = Code(codeChallengeMethod: .plain, codeChallenge: "123456")
        // because the value is different
        XCTAssertFalse(code1 == code2)
        XCTAssertFalse(code1 == code3)
    }

}
