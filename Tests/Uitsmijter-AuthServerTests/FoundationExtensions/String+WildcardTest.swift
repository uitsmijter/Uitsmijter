import Testing
@testable import Uitsmijter_AuthServer

@Suite("String Wildcard Extension Tests")
struct StringWildcardTest {

    @Test("String without wildcard match returns false")
    func nothingMatch() throws {
        #expect("abc".matchesWildcard(regex: "*.example.com") == false)
    }

    @Test("Subdomain host matches wildcard correctly")
    func subDomainHost() throws {
        #expect("foo.example.com".matchesWildcard(regex: "*.example.com") == true)
        #expect("foo.example.net".matchesWildcard(regex: "*.example.com") == false)
    }

    @Test("Inner host matches wildcard correctly")
    func innerHost() throws {
        #expect("foo.example.com".matchesWildcard(regex: "*.*.com") == true)
        #expect("foo.example.net".matchesWildcard(regex: "*.example.*") == true)
    }

    @Test("Multi subdomain host does not match single wildcard")
    func multiSubHost() throws {
        #expect("bar.foo.example.com".matchesWildcard(regex: "*.example.com") == false)
    }
}
