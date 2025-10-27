import Foundation
import Testing
import VaporTesting
@testable import Uitsmijter_AuthServer

/// Test the whole Plain Code flow
/// - User is not logged in
/// - Request a authorisation code
/// - Get the login Page
/// - Log in
/// - Gets the code redirect
///
@Suite("Auth Controller - Insecure Flow Cycle", .serialized)
struct AuthControllerCodeInsecureFlowCycleTest {
    let decoder = JSONDecoder()
    let testAppIdent = UUID()

    /// Flow Test
    ///
    /// - Throws: An error if something with the network went wrong
    @Test("Code flow with full request cycle")
    func testCodeFlowWFullRequestCycle() async throws {
        try await performFlowTest()
    }

    // swiftlint:disable:next function_body_length
    private func performFlowTest() async throws {
        // swiftlint:disable:next closure_body_length
        try await withApp(configure: configure) { app in
            await generateTestClient(in: app.entityStorage, uuid: testAppIdent)

            // 1. Request Code, get Login Page
            // -----------------------------------
            let testServerAddress = "http://\(app.http.server.configuration.hostname)"
                + ":\(app.http.server.configuration.port)"

            let authorizeUrl = "/authorize"
                + "?response_type=code"
                + "&client_id=\(testAppIdent.uuidString)"
                + "&redirect_uri=http://example.com/"
                + "&scope=test"
                + "&state=123"

            let expectedLocationString = "\(testServerAddress)/authorize"
                + "?response_type=code"
                + "&amp;client_id=\(testAppIdent)"
                + "&amp;redirect_uri=http://example.com/"
                + "&amp;scope=test"
                + "&amp;state=123"

            let expectedInput = "<input type=\"hidden\" name=\"location\" value=\""
                + "/authorize"
                + "?response_type=code"
                + "&amp;client_id=\(testAppIdent)"
                + "&amp;redirect_uri=http://example.com/"
                + "&amp;scope=test"
                + "&amp;state=123\""

            try await app.testing().test(.GET, authorizeUrl) { @Sendable res async in
                #expect(res.body.string.contains("<form action=\"/login\" method=\"post\">"))
                #expect(res.body.string.contains(expectedInput))
                // no cookie is send here!
                #expect(res.headers["set-cookie"].isEmpty, "There should be no cookie set, yet")
            }

            // 2. Login
            // -----------------------------------
            let loginFormLocation = expectedLocationString

            // Extract cookie from login response
            // swiftlint:disable closure_parameter_position
            let cookieString = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<String, Error>) in
                // swiftlint:enable closure_parameter_position
                Task {
                    do {
                        try await app.testing().test(
                            .POST,
                            "/login",
                            beforeRequest: { @Sendable req async throws in
                                // fill the form
                                try req.content.encode(LoginForm(
                                    username: "trumpet@example.com",
                                    password: "It Never Entered My Mind",
                                    location: loginFormLocation
                                ))
                            },
                            afterResponse: { @Sendable res async in
                            #expect(res.status == .seeOther)
                            #expect(res.headers["location"].first?.contains(expectedLocationString) == true)
                            #expect(res.headers.contains(name: .setCookie))

                            guard let cookie: HTTPCookies.Value = res.headers.setCookie?[Constants.COOKIE.NAME]
                            else {
                                Issue.record("No set cookie header")
                                continuation.resume(throwing: Abort(.badRequest))
                                return
                            }
                            continuation.resume(returning: cookie.serialize(name: Constants.COOKIE.NAME))
                            }
                        )
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // 3. follow the redirect
            // -----------------------------------
            let redirectUrl = "/authorize"
                + "?response_type=code"
                + "&client_id=\(testAppIdent)"
                + "&redirect_uri=http://example.com/"
                + "&scope=test&state=123"

            try await app.testing().test(
                .GET,
                redirectUrl,
                beforeRequest: { @Sendable req async in
                    req.headers.replaceOrAdd(name: "Cookie", value: cookieString)
                },
                afterResponse: { @Sendable res async throws in
                // 4. Get the second redirect with the code
                // -----------------------------------
                #expect(res.status == .seeOther)
                // #expect(res.headers.contains(name: .setCookie))
                #expect(res.headers.contains(name: .location))
                #expect(res.headers.contains(name: .authorization))

                #expect((res.headers.bearerAuthorization?.token.count ?? 0) > 8)
                guard let location = res.headers.first(name: "location") else {
                    Issue.record("Con not get location from headers")
                    throw Abort(.badRequest)
                }
                #expect(location.contains("example.com"))
                #expect(location.contains("code="))
                #expect(location.contains("state=123"))

                let codeGroups = try location.groups(regex: "code=([a-zA-Z0-9]+)")
                #expect(codeGroups.count == 2)
                let code = codeGroups[1]
                #expect(code.count == Constants.TOKEN.LENGTH)
                }
            )
        }
    }
}
