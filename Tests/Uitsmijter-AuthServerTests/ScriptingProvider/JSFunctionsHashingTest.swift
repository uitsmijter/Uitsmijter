import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("JavaScript Functions Hashing Tests")
struct JSFunctionsHashingTest {

    @Test("MD5 hash function works correctly")
    func md5() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
                                                  function test(){
                                                  return md5("Hello");
                                                  }
                                                  test();
                                                  """)
        #expect(result == "\"8b1a9953c4611296a827abf8c47804d7\"")
    }

    @Test("MD5 with null returns null")
    func md5Null() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
                                                  function test(){
                                                  return md5();
                                                  }
                                                  test();
                                                  """)
        #expect(result == "null")
    }

    @Test("SHA256 hash function works correctly")
    func sha256() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
                                                  function test(){
                                                  return sha256("Hello");
                                                  }
                                                  test();
                                                  """)
        #expect(result == "\"185f8db32271fe25f561a6fc938b2e264306ec304eda518007d1764826381969\"")
    }

    @Test("SHA256 with null returns null")
    func sha256Null() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
                                                  function test(){
                                                  return sha256();
                                                  }
                                                  test();
                                                  """)
        #expect(result == "null")
    }
}
