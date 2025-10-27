import Foundation
@testable import Uitsmijter_AuthServer
import Testing
import JXKit

@Suite("JXContext Ident Extension Tests")
struct JXContextIdentTest {

    @Test("ident returns non-empty string")
    func identReturnsNonEmptyString() {
        let context = JXContext()
        let identifier = context.ident

        #expect(identifier.isEmpty == false)
    }

    @Test("ident returns string representation")
    func identReturnsStringRepresentation() {
        let context = JXContext()
        let identifier = context.ident

        // Verify it's a valid string by checking it has content
        #expect(!identifier.isEmpty)
    }

    @Test("ident is consistent across multiple calls")
    func identIsConsistent() {
        let context = JXContext()
        let id1 = context.ident
        let id2 = context.ident

        #expect(id1 == id2)
    }

    @Test("different contexts have different idents")
    func differentContextsHaveDifferentIdents() {
        let context1 = JXContext()
        let context2 = JXContext()

        let id1 = context1.ident
        let id2 = context2.ident

        // Different contexts should have different identifiers
        #expect(id1 != id2)
    }

    @Test("ident contains memory address information")
    func identContainsMemoryAddress() {
        let context = JXContext()
        let identifier = context.ident

        // Debug descriptions typically contain memory addresses in hex format (0x...)
        #expect(identifier.contains("0x"))
    }

    @Test("ident can be used for logging")
    func identCanBeUsedForLogging() {
        let context = JXContext()
        let logMessage = "Context: \(context.ident)"

        // Verify the log message contains the context identifier
        #expect(logMessage.contains(context.ident))
        #expect(logMessage.hasPrefix("Context: "))
    }

    @Test("ident works with multiple contexts in sequence")
    func identWorksWithMultipleContexts() {
        var contexts: [JXContext] = []
        for _ in 0..<5 {
            let context = JXContext()
            contexts.append(context)
        }
        let identifiers: [String] = contexts.map(\.ident)

        // All identifiers should be non-empty
        #expect(identifiers.allSatisfy { !$0.isEmpty })

        // All identifiers should be unique
        let uniqueIdentifiers = Set(identifiers)
        #expect(uniqueIdentifiers.count == identifiers.count)
    }
}
