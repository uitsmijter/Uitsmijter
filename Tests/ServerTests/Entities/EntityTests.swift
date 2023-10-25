@testable import Server
import XCTVapor

final class EntityTests: XCTestCase {

    func testEntityResourceReferenceFileEqualsSame() throws {
        guard let url = URL(string: "/tmp/test.yml") else {
            throw TestError.fail(withError: "/tmp/test.yaml is an invalid url.")
        }

        let resA = EntityResourceReference.file(url)
        let resB = EntityResourceReference.file(url)

        XCTAssertEqual(resA, resB, "Different EntityResource to same url should be equals")
        XCTAssertEqual(resB, resA, "Different EntityResource to same url should be equals")
    }

    func testEntityResourceReferenceFileNotEqualsSame() throws {
        guard let urlFoo = URL(string: "/tmp/foo.yml"), let urlBar = URL(string: "/tmp/bar.yml") else {
            throw TestError.fail(withError: "/tmp/{foo,bar}.yaml is an invalid url.")
        }

        let resA = EntityResourceReference.file(urlFoo)
        let resB = EntityResourceReference.file(urlBar)

        XCTAssertNotEqual(resA, resB, "EntityResource to different urls should not be equals")
        XCTAssertNotEqual(resB, resA, "EntityResource to different urls should not be equals")
    }

    func testEntityResourceReferenceKubernetesEqualsSame() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid, "1337")
        let resB = EntityResourceReference.kubernetes(uuid, "1337")

        XCTAssertEqual(resA, resA, "Same EntityResource of kubernetes with res anf rev should be equals")
        XCTAssertEqual(resA, resB, "Different EntityResource of kubernetes with same res and rev should be equals")
    }

    func testEntityResourceReferenceKubernetesEqualsSameEmptyReference() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid)
        let resB = EntityResourceReference.kubernetes(uuid)

        XCTAssertEqual(resA, resB, "Different EntityResource of kubernetes with same res and w/o rev should be equals")
    }

    func testEntityResourceReferenceKubernetesEqualsSameWithoutReference() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid, "1337")
        let resB = EntityResourceReference.kubernetes(uuid)

        XCTAssertEqual(resA, resB, "Different Kubernetes Resources on same res, but without res should match")
        XCTAssertEqual(resB, resA, "Different Kubernetes Resources on same res, but without res should match")
    }

    func testEntityResourceReferenceKubernetesNotEqualsById() throws {
        let resA = EntityResourceReference.kubernetes(UUID(), "0")
        let resB = EntityResourceReference.kubernetes(UUID(), "0")

        XCTAssertNotEqual(resA, resB, "Different Kubernetes Resources with the same rev should be different")
    }

    func testEntityResourceReferenceKubernetesNotEqualsByReference() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid, "42")
        let resB = EntityResourceReference.kubernetes(uuid, "1337")

        XCTAssertNotEqual(
                resA,
                resB,
                "Different Kubernetes Resources with the same res but different res should not match"
        )
    }

    func testEntityResourceReferenceKubernetesNotEqualsSameEmptyReference() throws {
        let resA = EntityResourceReference.kubernetes(UUID())
        let resB = EntityResourceReference.kubernetes(UUID())

        XCTAssertNotEqual(
                resA,
                resB,
                "Different Kubernetes Resources with the different res and no rev should not match"
        )
    }

    func testEntityResourceReferenceDifferentType() throws {
        guard let url = URL(string: "/tmp/test.yml") else {
            throw TestError.fail(withError: "/tmp/test.yaml is an invalid url.")
        }

        let resA = EntityResourceReference.kubernetes(UUID())
        let resB = EntityResourceReference.file(url)

        XCTAssertNotEqual(resA, resB, "EntityResources of different type should not match")
        XCTAssertNotEqual(resB, resA, "EntityResources of different type should not match")
    }

    func testEntityResourceNil() throws {
        let resA = EntityResourceReference.kubernetes(UUID())
        let notInitialised: EntityResourceReference? = nil

        XCTAssertNotEqual(resA, notInitialised)
        XCTAssertNotEqual(notInitialised, resA)
        XCTAssertEqual(notInitialised, notInitialised)
    }

}
