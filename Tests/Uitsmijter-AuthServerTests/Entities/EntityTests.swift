import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@Suite("Entity Tests")
@MainActor
struct EntityTests {

    @Test("Entity resource reference file equals same")
    func entityResourceReferenceFileEqualsSame() throws {
        guard let url = URL(string: "/tmp/test.yml") else {
            Issue.record("/tmp/test.yaml is an invalid url.")
            return
        }

        let resA = EntityResourceReference.file(url)
        let resB = EntityResourceReference.file(url)

        #expect(resA == resB, "Different EntityResource to same url should be equals")
        #expect(resB == resA, "Different EntityResource to same url should be equals")
    }

    @Test("Entity resource reference file not equals same")
    func entityResourceReferenceFileNotEqualsSame() throws {
        guard let urlFoo = URL(string: "/tmp/foo.yml"), let urlBar = URL(string: "/tmp/bar.yml") else {
            Issue.record("/tmp/{foo,bar}.yaml is an invalid url.")
            return
        }

        let resA = EntityResourceReference.file(urlFoo)
        let resB = EntityResourceReference.file(urlBar)

        #expect(resA != resB, "EntityResource to different urls should not be equals")
        #expect(resB != resA, "EntityResource to different urls should not be equals")
    }

    @Test("Entity resource reference kubernetes equals same")
    func entityResourceReferenceKubernetesEqualsSame() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid, "1337")
        let resB = EntityResourceReference.kubernetes(uuid, "1337")

        #expect(resA == resA, "Same EntityResource of kubernetes with res anf rev should be equals")
        #expect(resA == resB, "Different EntityResource of kubernetes with same res and rev should be equals")
    }

    @Test("Entity resource reference kubernetes equals same empty reference")
    func entityResourceReferenceKubernetesEqualsSameEmptyReference() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid)
        let resB = EntityResourceReference.kubernetes(uuid)

        #expect(resA == resB, "Different EntityResource of kubernetes with same res and w/o rev should be equals")
    }

    @Test("Entity resource reference kubernetes equals same without reference")
    func entityResourceReferenceKubernetesEqualsSameWithoutReference() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid, "1337")
        let resB = EntityResourceReference.kubernetes(uuid)

        #expect(resA == resB, "Different Kubernetes Resources on same res, but without res should match")
        #expect(resB == resA, "Different Kubernetes Resources on same res, but without res should match")
    }

    @Test("Entity resource reference kubernetes not equals by id")
    func entityResourceReferenceKubernetesNotEqualsById() throws {
        let resA = EntityResourceReference.kubernetes(UUID(), "0")
        let resB = EntityResourceReference.kubernetes(UUID(), "0")

        #expect(resA != resB, "Different Kubernetes Resources with the same rev should be different")
    }

    @Test("Entity resource reference kubernetes not equals by reference")
    func entityResourceReferenceKubernetesNotEqualsByReference() throws {
        let uuid = UUID()

        let resA = EntityResourceReference.kubernetes(uuid, "42")
        let resB = EntityResourceReference.kubernetes(uuid, "1337")

        #expect(
            resA != resB,
            "Different Kubernetes Resources with the same res but different res should not match"
        )
    }

    @Test("Entity resource reference kubernetes not equals same empty reference")
    func entityResourceReferenceKubernetesNotEqualsSameEmptyReference() throws {
        let resA = EntityResourceReference.kubernetes(UUID())
        let resB = EntityResourceReference.kubernetes(UUID())

        #expect(
            resA != resB,
            "Different Kubernetes Resources with the different res and no rev should not match"
        )
    }

    @Test("Entity resource reference different type")
    func entityResourceReferenceDifferentType() throws {
        guard let url = URL(string: "/tmp/test.yml") else {
            Issue.record("/tmp/test.yaml is an invalid url.")
            return
        }

        let resA = EntityResourceReference.kubernetes(UUID())
        let resB = EntityResourceReference.file(url)

        #expect(resA != resB, "EntityResources of different type should not match")
        #expect(resB != resA, "EntityResources of different type should not match")
    }

    @Test("Entity resource nil")
    func entityResourceNil() throws {
        let resA = EntityResourceReference.kubernetes(UUID())
        let notInitialised: EntityResourceReference? = nil

        #expect(resA != notInitialised)
        #expect(notInitialised != resA)
        #expect(notInitialised == notInitialised)
    }

}
