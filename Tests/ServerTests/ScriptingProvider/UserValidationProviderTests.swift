import Foundation

@testable import Server
import XCTVapor

final class UserValidationProviderTests: XCTestCase {

    let providerScript = """
                         class UserValidationProvider {
                            isValid = false;
                            constructor(args) {
                                 if(args.username == "ok@example.com"){
                                      this.isValid = true;
                                 }
                                 commit(true);
                            }

                            // Getter
                            get isValid() {
                               return this.isValid;
                            }
                         }
                         """

    let userOK = JSInputUsername(username: "ok@example.com")
    let userDenied = JSInputUsername(username: "deni@example.com")

    func testGetExampleCallback() async throws {
        try XCTSkipIf(true)
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScript)
        let expect = expectation(description: "userValidate response")
        cbi.start(class: .userValidate, arguments: userOK) { result in
            do {
                let bodies = try result.get()
                XCTAssertEqual(bodies.count, 1)
                guard let firstBody = bodies.first else {
                    XCTFail("No body available")
                    return
                }
                XCTAssertContains(firstBody, "true")
                expect.fulfill()
            } catch {
                if let err = error as? JavaScriptProvider.JavaScriptError {
                    switch err {
                    case .timeout:
                        XCTAssert(false, "Call timed out)")
                    default:
                        XCTAssert(false, "other error. \(error.localizedDescription)")
                    }
                }
            }
        }
        wait(for: [expect], timeout: TestDefaults.waitTimeout)
    }

    func testIsValid() async throws {
        try XCTSkipIf(true)
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScript)
        _ = try await cbi.start(class: .userValidate, arguments: userOK)

        let isValid: Bool = try cbi.getValue(class: .userValidate, property: "isValid")
        XCTAssertTrue(isValid)
    }

    func testIsInvalid() async throws {
        try XCTSkipIf(true)
        let cbi = JavaScriptProvider()
        try cbi.loadProvider(script: providerScript)
        _ = try await cbi.start(class: .userValidate, arguments: userDenied)

        let isValid: Bool = try cbi.getValue(class: .userValidate, property: "isValid")
        XCTAssertFalse(isValid)
    }
}
