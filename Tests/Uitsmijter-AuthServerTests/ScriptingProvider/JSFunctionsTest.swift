import VaporTesting
import Foundation
import Testing
@testable import Uitsmijter_AuthServer

@Suite("JavaScript Functions Tests")
struct JSFunctionsTest {

    @Test("say function logs info messages")
    func sayLogsInfoMessages() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                say("Hello from JavaScript");
                return "done";
            }
            test();
        """)

        #expect(result == "\"done\"")
    }

    @Test("say function logs multiple arguments")
    func sayLogsMultipleArguments() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                say("Multiple", "arguments", "test");
                return "completed";
            }
            test();
        """)

        #expect(result == "\"completed\"")
    }

    @Test("console.log works as alias for say")
    func consoleLogWorks() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                console.log("Testing console.log");
                return "logged";
            }
            test();
        """)

        #expect(result == "\"logged\"")
    }

    @Test("console.error logs error messages")
    func consoleErrorLogsErrors() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                console.error("This is an error message");
                return "error_logged";
            }
            test();
        """)

        #expect(result == "\"error_logged\"")
    }

    @Test("console.log and console.error can be used together")
    func consoleLogAndErrorTogether() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                console.log("Info message");
                console.error("Error message");
                return "both_logged";
            }
            test();
        """)

        #expect(result == "\"both_logged\"")
    }

    @Test("commit function is available in scripts")
    func commitFunctionIsAvailable() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                // Just verify commit exists as a function
                var hasCommit = typeof commit === 'function';
                return hasCommit ? "commit_exists" : "no_commit";
            }
            test();
        """)

        #expect(result == "\"commit_exists\"")
    }

    @Test("all functions can be used in same script")
    func allFunctionsCanBeUsedTogether() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                console.log("Starting test");
                var hash = md5("test");
                console.error("Computed hash:", hash);
                say("All functions working");
                return "success";
            }
            test();
        """)

        #expect(result == "\"success\"")
    }

    @Test("say function with no arguments")
    func sayWithNoArguments() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                say();
                return "called_without_args";
            }
            test();
        """)

        #expect(result == "\"called_without_args\"")
    }

    @Test("say function with number argument")
    func sayWithNumberArgument() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                say(42);
                return "logged_number";
            }
            test();
        """)

        #expect(result == "\"logged_number\"")
    }

    @Test("say function with boolean argument")
    func sayWithBooleanArgument() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                say(true, false);
                return "logged_boolean";
            }
            test();
        """)

        #expect(result == "\"logged_boolean\"")
    }

    @Test("functions work in complex script with variables")
    func functionsInComplexScript() async throws {
        let jsp = JavaScriptProvider()
        let result = try await jsp.loadProvider(script: """
            function test() {
                var name = "TestUser";
                var password = "secret123";

                console.log("Authenticating user:", name);
                var hash = md5(password);
                console.log("Password hash:", hash);

                if (hash) {
                    say("Hash computed successfully");
                    return "authenticated";
                }

                console.error("Authentication failed");
                return "failed";
            }
            test();
        """)

        #expect(result == "\"authenticated\"")
    }
}
