import Foundation

@testable import Server
import XCTVapor

final class JSFunctionsHashingTest: XCTestCase {

    func testMd5() async throws {
        let jsp = JavaScriptProvider()
        let result = try jsp.loadProvider(script: """
                                                  function test(){
                                                  return md5("Hello");
                                                  }
                                                  test();
                                                  """)
        XCTAssertEqual(result, "\"8b1a9953c4611296a827abf8c47804d7\"")
    }

    func testMd5Null() async throws {
        let jsp = JavaScriptProvider()
        let result = try jsp.loadProvider(script: """
                                                  function test(){
                                                  return md5();
                                                  }
                                                  test();
                                                  """)
        XCTAssertEqual(result, "null")
    }

    func testSha256() async throws {
        let jsp = JavaScriptProvider()
        let result = try jsp.loadProvider(script: """
                                                  function test(){
                                                  return sha256("Hello");
                                                  }
                                                  test();
                                                  """)
        XCTAssertEqual(result, "\"185f8db32271fe25f561a6fc938b2e264306ec304eda518007d1764826381969\"")
    }

    func testSha256Null() async throws {
        let jsp = JavaScriptProvider()
        let result = try jsp.loadProvider(script: """
                                                  function test(){
                                                  return sha256();
                                                  }
                                                  test();
                                                  """)
        XCTAssertEqual(result, "null")
    }
}
