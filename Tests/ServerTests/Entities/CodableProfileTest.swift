import Foundation
import XCTVapor
@testable import Server

final class CodableProfileTest: XCTestCase {

    func testProfileIsAString() async throws {
        guard let data = "\"Hello\"".data(using: .utf8) else {
            return XCTFail("No data")
        }
        let json = try JSONDecoder().decode(CodableProfile.self, from: data)
        XCTAssertEqual(json.string, "Hello")
    }

    func testProfileIsAInt() async throws {
        guard let data = "768".data(using: .utf8) else {
            return XCTFail("No data")
        }
        let json = try JSONDecoder().decode(CodableProfile.self, from: data)
        XCTAssertEqual(json.int, 768)
    }

    func testProfileIsABool() async throws {
        guard let dataTrue = "true".data(using: .utf8) else {
            return XCTFail("No data")
        }
        let jsonTrue = try JSONDecoder().decode(CodableProfile.self, from: dataTrue)
        XCTAssertTrue(jsonTrue.bool!) // swiftlint:disable:this force_unwrapping

        guard let dataFalse = "false".data(using: .utf8) else {
            return XCTFail("No data")
        }
        let jsonFalse = try JSONDecoder().decode(CodableProfile.self, from: dataFalse)
        XCTAssertFalse(jsonFalse.bool!) // swiftlint:disable:this force_unwrapping
    }

    func testProfileIsNotParseable() async throws {
        guard let data = "124BoolNotString".data(using: .utf8) else {
            return XCTFail("No data")
        }
        XCTAssertThrowsError(try JSONDecoder().decode(CodableProfile.self, from: data))

    }

    func testProfileIsArray() async throws {
        guard let data = """
                         ["John Doe", "Sander Foles", "Lorene Ibsen"]
                         """.data(using: .utf8)
        else {
            return XCTFail("No data")
        }
        let json = try JSONDecoder().decode(CodableProfile.self, from: data)
        XCTAssertEqual(json.array?[0].string, "John Doe")
        XCTAssertEqual(json.array?[1].string, "Sander Foles")
    }

    func testProfileIsObject() async throws {
        guard let data = """
                         {
                          "name": "John Doe",
                          "born": 1937
                         }
                         """.data(using: .utf8)
        else {
            return XCTFail("No data")
        }
        let json = try JSONDecoder().decode(CodableProfile.self, from: data)
        XCTAssertEqual(json.object?["name"]?.string, "John Doe")
        XCTAssertEqual(json.object?["born"]?.int, 1937)
    }

    func testProfileIsNestedObject() async throws {
        guard let data = """
                         {
                          "name": "John Doe",
                          "address": {
                            "street": "Basslane"
                          }
                         }
                         """.data(using: .utf8)
        else {
            return XCTFail("No data")
        }
        let json = try JSONDecoder().decode(CodableProfile.self, from: data)
        XCTAssertEqual(json.object?["name"]?.string, "John Doe")
        XCTAssertEqual(json.object?["address"]?.object?["street"]?.string, "Basslane")
    }

}
