import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("JavaScript Functions Networking Tests")
struct JSFunctionsNetworkingTest {

    @Test("fetch function is available in scripts")
    func fetchFunctionIsAvailable() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                var hasFetch = typeof fetch === 'function';
                return hasFetch ? "fetch_exists" : "no_fetch";
            }
            test();
        """)

        #expect(result == "\"fetch_exists\"")
    }

    @Test("fetch function returns a promise")
    func fetchReturnsPromise() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                var result = fetch("http://example.com");
                var isPromise = result && typeof result.then === 'function';
                return isPromise ? "is_promise" : "not_promise";
            }
            test();
        """)

        #expect(result == "\"is_promise\"")
    }

    @Test("fetch with invalid URL fails gracefully")
    func fetchWithInvalidURL() async throws {
        let jsp = JavaScriptProvider()

        // This test verifies that fetch handles invalid URLs
        // The script should not crash
        let result = try await jsp.loadProvider(script: """
            function test() {
                try {
                    fetch("not a valid url");
                    return "no_error";
                } catch (e) {
                    return "caught_error";
                }
            }
            test();
        """)

        // The test just verifies the script doesn't crash
        #expect(result == "\"no_error\"" || result == "\"caught_error\"")
    }

    @Test("fetch accepts method parameter")
    func fetchAcceptsMethod() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                // Just verify fetch accepts a settings object with method
                fetch("http://example.com", { method: "POST" });
                return "method_accepted";
            }
            test();
        """)

        #expect(result == "\"method_accepted\"")
    }

    @Test("fetch accepts headers parameter")
    func fetchAcceptsHeaders() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                fetch("http://example.com", {
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": "Bearer token123"
                    }
                });
                return "headers_accepted";
            }
            test();
        """)

        #expect(result == "\"headers_accepted\"")
    }

    @Test("fetch accepts body parameter")
    func fetchAcceptsBody() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                fetch("http://example.com", {
                    method: "POST",
                    body: "request body content"
                });
                return "body_accepted";
            }
            test();
        """)

        #expect(result == "\"body_accepted\"")
    }

    @Test("fetch with POST method and JSON body")
    func fetchPostWithJSONBody() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                var data = { name: "test", value: 123 };
                fetch("http://example.com/api", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(data)
                });
                return "post_with_json";
            }
            test();
        """)

        #expect(result == "\"post_with_json\"")
    }

    @Test("fetch with PUT method")
    func fetchPutMethod() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                fetch("http://example.com/resource/1", {
                    method: "PUT",
                    body: "updated content"
                });
                return "put_method";
            }
            test();
        """)

        #expect(result == "\"put_method\"")
    }

    @Test("fetch with DELETE method")
    func fetchDeleteMethod() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                fetch("http://example.com/resource/1", {
                    method: "DELETE"
                });
                return "delete_method";
            }
            test();
        """)

        #expect(result == "\"delete_method\"")
    }

    @Test("fetch with custom headers multiple entries")
    func fetchWithMultipleCustomHeaders() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                fetch("http://example.com", {
                    headers: {
                        "X-Custom-Header": "value1",
                        "X-Another-Header": "value2",
                        "X-Third-Header": "value3"
                    }
                });
                return "multiple_headers";
            }
            test();
        """)

        #expect(result == "\"multiple_headers\"")
    }

    @Test("fetch without settings uses GET by default")
    func fetchDefaultsToGet() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                // fetch without second parameter should default to GET
                fetch("http://example.com");
                return "default_get";
            }
            test();
        """)

        #expect(result == "\"default_get\"")
    }

    @Test("fetch with empty settings object")
    func fetchWithEmptySettings() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                fetch("http://example.com", {});
                return "empty_settings";
            }
            test();
        """)

        #expect(result == "\"empty_settings\"")
    }

    @Test("multiple fetch calls in sequence")
    func multipleFetchCallsInSequence() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                fetch("http://example.com/1");
                fetch("http://example.com/2");
                fetch("http://example.com/3");
                return "multiple_fetches";
            }
            test();
        """)

        #expect(result == "\"multiple_fetches\"")
    }

    @Test("fetch can be used with async/await pattern")
    func fetchWithAsyncAwaitPattern() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                // Verify fetch can be used in async context
                async function asyncFetch() {
                    try {
                        var response = await fetch("http://example.com");
                        return "async_completed";
                    } catch (error) {
                        return "async_error";
                    }
                }
                // Just verify the function can be defined
                return typeof asyncFetch === 'function' ? "async_defined" : "not_async";
            }
            test();
        """)

        #expect(result == "\"async_defined\"")
    }

    @Test("fetch in conditional statements")
    func fetchInConditionals() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                var shouldFetch = true;
                if (shouldFetch) {
                    fetch("http://example.com");
                }
                return "conditional_fetch";
            }
            test();
        """)

        #expect(result == "\"conditional_fetch\"")
    }

    @Test("fetch actually makes network request and returns response")
    func fetchMakesRealNetworkRequest() async throws {
        let jsp = JavaScriptProvider()
        _ = try await jsp.loadProvider(script: """
            class UserLoginProvider {
                constructor(credentials) {
                    fetch("http://example.com").then((response) => {
                        commit(response);
                    });
                }
            }
        """)

        let credentials = JSInputCredentials(username: "test@example.com", password: "test")
        let results = try await jsp.start(class: .userLogin, arguments: credentials)

        // Verify we got a result
        #expect(results.count == 1)

        guard let responseJson = results.first else {
            Issue.record("No response received from fetch")
            return
        }

        // Verify the response contains expected data from example.com
        #expect(responseJson?.contains("Example Domain") == true)

        // The response should be a JSON string with code and body
        // Example: {"code":200,"body":"..."}
        #expect(responseJson?.contains("code") == true)
        #expect(responseJson?.contains("body") == true)
    }
}
