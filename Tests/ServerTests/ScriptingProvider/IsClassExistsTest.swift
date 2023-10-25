import Foundation

@testable import Server
import XCTVapor

final class IsClassExistsTest: XCTestCase {

    func testClassExists() async throws {
        let jsp = JavaScriptProvider()
        _ = try jsp.loadProvider(script: """
                                         class UserLoginProvider {
                                           constructor(){};
                                         }
                                         """)
        let result = jsp.isClassExists(class: .userLogin)
        XCTAssertTrue(result)
    }

    func testClassDoNotExists() async throws {
        let jsp = JavaScriptProvider()
        _ = try jsp.loadProvider(script: """
                                         class UserLoginProvider {
                                           constructor(){};
                                         }
                                         """)
        let result = jsp.isClassExists(class: .userValidate)
        XCTAssertFalse(result)
    }
}
