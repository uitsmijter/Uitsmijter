import Foundation
@testable import Uitsmijter_AuthServer
import Testing

@Suite("UUID Empty Extension Tests")
struct UUIDEmptyTest {

    @Test("UUID.empty returns zero UUID")
    func emptyReturnsZeroUUID() {
        let emptyUUID = UUID.empty
        let expectedString = "00000000-0000-0000-0000-000000000000"

        #expect(emptyUUID.uuidString.lowercased() == expectedString)
    }

    @Test("UUID.empty is always the same value")
    func emptyIsConsistent() {
        let empty1 = UUID.empty
        let empty2 = UUID.empty

        // Should have the same UUID value
        #expect(empty1.uuidString == empty2.uuidString)
        #expect(empty1 == empty2)
    }

    @Test("UUID.empty is different from a random UUID")
    func emptyIsDifferentFromRandom() {
        let emptyUUID = UUID.empty
        let randomUUID = UUID()

        #expect(emptyUUID != randomUUID)
    }

    @Test("UUID.empty can be used as a placeholder")
    func emptyAsPlaceholder() {
        // Simulating a scenario where empty UUID is used as a placeholder
        struct Record {
            var id: UUID
            var name: String
        }

        let record = Record(id: UUID.empty, name: "Placeholder")

        #expect(record.id == UUID.empty)
        #expect(record.id.uuidString.lowercased() == "00000000-0000-0000-0000-000000000000")
    }

    @Test("UUID.empty is a valid UUID")
    func emptyIsValidUUID() {
        let emptyUUID = UUID.empty

        // Should be able to convert to string and back
        let recreated = UUID(uuidString: emptyUUID.uuidString)
        #expect(recreated != nil)
        #expect(recreated == emptyUUID)
    }

    @Test("UUID.empty has all zero bytes")
    func emptyHasZeroBytes() {
        let emptyUUID = UUID.empty

        // Get the UUID bytes representation
        let uuidString = emptyUUID.uuidString
        let components = uuidString.split(separator: "-")

        // Verify structure: 8-4-4-4-12 format
        #expect(components.count == 5)
        #expect(components[0].count == 8)
        #expect(components[1].count == 4)
        #expect(components[2].count == 4)
        #expect(components[3].count == 4)
        #expect(components[4].count == 12)

        // All components should be zeros
        for component in components {
            #expect(component.allSatisfy { $0 == "0" })
        }
    }

    @Test("UUID.empty can be used in collections")
    func emptyInCollections() {
        var uuidSet: Set<UUID> = []

        uuidSet.insert(UUID.empty)
        uuidSet.insert(UUID())
        uuidSet.insert(UUID.empty) // Should not add duplicate

        #expect(uuidSet.count == 2)
        #expect(uuidSet.contains(UUID.empty))
    }

    @Test("UUID.empty can be compared with other UUIDs")
    func emptyComparison() {
        let empty = UUID.empty
        guard let nonEmpty = UUID(uuidString: "12345678-1234-1234-1234-123456789012") else {
            Issue.record("Failed to create non-empty UUID")
            return
        }

        #expect(empty != nonEmpty)
        #expect(empty == UUID.empty)

        // UUID comparison is based on the underlying bytes
        guard let anotherEmpty = UUID(uuidString: "00000000-0000-0000-0000-000000000000") else {
            Issue.record("Failed to create another empty UUID")
            return
        }
        #expect(empty == anotherEmpty)
    }
}
