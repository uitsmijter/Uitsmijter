import Testing
@testable import FoundationExtensions

@Suite("String Slug Extension Tests")
struct StringSlugTest {

    @Test("String with no slugging needed remains unchanged")
    func nothingToSlug() throws {
        let results: String? = "hello-7".slug
        #expect(results?.count == 7)
        #expect(results == "hello-7")
    }

    @Test("String with special characters is properly slugged")
    func somethingToSlug() throws {
        let results: String? = "Hello_7 What is a / name".slug
        #expect(results == "hello-7-what-is-a-name")
    }
}
