import Testing
@testable import Uitsmijter_AuthServer
import Foundation

@Suite("JSInputParameter Protocol Tests")
struct JSInputParameterTest {

    // MARK: - JSInputUsername Tests

    @Test("JSInputUsername initializes with username")
    func jsInputUsernameInitialization() throws {
        let username = JSInputUsername(username: "test@example.com")
        #expect(username.username == "test@example.com")
    }

    @Test("JSInputUsername toJSON produces valid JSON")
    func jsInputUsernameToJSON() throws {
        let username = JSInputUsername(username: "test@example.com")
        let json = try username.toJSON()

        #expect(json != nil)
        #expect(json?.contains("test@example.com") == true)
        #expect(json?.contains("username") == true)
    }

    @Test("JSInputUsername toJSON format is correct")
    func jsInputUsernameJSONFormat() throws {
        let username = JSInputUsername(username: "user@test.com")
        let json = try username.toJSON()

        #expect(json == "{\"username\":\"user@test.com\"}")
    }

    @Test("JSInputUsername encodes to JSON with special characters")
    func jsInputUsernameWithSpecialChars() throws {
        let username = JSInputUsername(username: "test+user@example.com")
        let json = try username.toJSON()

        #expect(json?.contains("test+user@example.com") == true)
    }

    @Test("JSInputUsername encodes to JSON with unicode")
    func jsInputUsernameWithUnicode() throws {
        let username = JSInputUsername(username: "用户@example.com")
        let json = try username.toJSON()

        #expect(json != nil)
        #expect(json?.isEmpty == false)
    }

    @Test("JSInputUsername encodes empty string")
    func jsInputUsernameEmpty() throws {
        let username = JSInputUsername(username: "")
        let json = try username.toJSON()

        #expect(json == "{\"username\":\"\"}")
    }

    @Test("JSInputUsername decodes from JSON")
    func jsInputUsernameDecoding() throws {
        let jsonData = Data("""
        {"username":"decoded@example.com"}
        """.utf8)

        let decoded = try JSONDecoder().decode(JSInputUsername.self, from: jsonData)
        #expect(decoded.username == "decoded@example.com")
    }

    @Test("JSInputUsername round-trip encoding and decoding")
    func jsInputUsernameRoundTrip() throws {
        let original = JSInputUsername(username: "roundtrip@test.com")
        let json = try original.toJSON()

        guard let jsonString = json else {
            Issue.record("Failed to encode JSInputUsername to JSON")
            return
        }
        let jsonData = Data(jsonString.utf8)
        let decoded = try JSONDecoder().decode(JSInputUsername.self, from: jsonData)

        #expect(decoded.username == original.username)
    }

    // MARK: - JSInputCredentials Tests

    @Test("JSInputCredentials initializes with username and password")
    func jsInputCredentialsInitialization() throws {
        let credentials = JSInputCredentials(username: "user@test.com", password: "secret123")
        #expect(credentials.username == "user@test.com")
        #expect(credentials.password == "secret123")
    }

    @Test("JSInputCredentials toJSON produces valid JSON")
    func jsInputCredentialsToJSON() throws {
        let credentials = JSInputCredentials(username: "user@test.com", password: "pass123")
        let json = try credentials.toJSON()

        #expect(json != nil)
        #expect(json?.contains("user@test.com") == true)
        #expect(json?.contains("pass123") == true)
        #expect(json?.contains("username") == true)
        #expect(json?.contains("password") == true)
    }

    @Test("JSInputCredentials toJSON format is correct")
    func jsInputCredentialsJSONFormat() throws {
        let credentials = JSInputCredentials(username: "user@test.com", password: "mypass")
        let json = try credentials.toJSON()

        // Order might vary, so check both possibilities
        let validFormat1 = "{\"username\":\"user@test.com\",\"password\":\"mypass\"}"
        let validFormat2 = "{\"password\":\"mypass\",\"username\":\"user@test.com\"}"

        #expect(json == validFormat1 || json == validFormat2)
    }

    @Test("JSInputCredentials encodes with special characters")
    func jsInputCredentialsWithSpecialChars() throws {
        let credentials = JSInputCredentials(username: "test+user@example.com", password: "p@ss!word#123")
        let json = try credentials.toJSON()

        #expect(json?.contains("test+user@example.com") == true)
        #expect(json?.contains("p@ss!word#123") == true)
    }

    @Test("JSInputCredentials encodes with empty password")
    func jsInputCredentialsEmptyPassword() throws {
        let credentials = JSInputCredentials(username: "user@test.com", password: "")
        let json = try credentials.toJSON()

        #expect(json?.contains("user@test.com") == true)
        #expect(json?.contains("password") == true)
    }

    @Test("JSInputCredentials encodes with empty username")
    func jsInputCredentialsEmptyUsername() throws {
        let credentials = JSInputCredentials(username: "", password: "password")
        let json = try credentials.toJSON()

        #expect(json?.contains("username") == true)
        #expect(json?.contains("password") == true)
    }

    @Test("JSInputCredentials encodes with unicode")
    func jsInputCredentialsWithUnicode() throws {
        let credentials = JSInputCredentials(username: "用户@example.com", password: "密码123")
        let json = try credentials.toJSON()

        #expect(json != nil)
        #expect(json?.isEmpty == false)
    }

    @Test("JSInputCredentials decodes from JSON")
    func jsInputCredentialsDecoding() throws {
        let jsonData = Data("""
        {"username":"decoded@example.com","password":"decodedpass"}
        """.utf8)

        let decoded = try JSONDecoder().decode(JSInputCredentials.self, from: jsonData)
        #expect(decoded.username == "decoded@example.com")
        #expect(decoded.password == "decodedpass")
    }

    @Test("JSInputCredentials round-trip encoding and decoding")
    func jsInputCredentialsRoundTrip() throws {
        let original = JSInputCredentials(username: "roundtrip@test.com", password: "roundtrippass")
        let json = try original.toJSON()

        guard let jsonString = json else {
            Issue.record("Failed to encode JSInputCredentials to JSON")
            return
        }
        let jsonData = Data(jsonString.utf8)
        let decoded = try JSONDecoder().decode(JSInputCredentials.self, from: jsonData)

        #expect(decoded.username == original.username)
        #expect(decoded.password == original.password)
    }

    // MARK: - Protocol Conformance Tests

    @Test("JSInputUsername conforms to JSInputParameterProtocol")
    func jsInputUsernameConformsToProtocol() throws {
        let username: any JSInputParameterProtocol = JSInputUsername(username: "test@example.com")
        let json = try username.toJSON()

        #expect(json != nil)
    }

    @Test("JSInputCredentials conforms to JSInputParameterProtocol")
    func jsInputCredentialsConformsToProtocol() throws {
        let credentials: any JSInputParameterProtocol = JSInputCredentials(
            username: "test@example.com",
            password: "password"
        )
        let json = try credentials.toJSON()

        #expect(json != nil)
    }

    @Test("JSInputUsername conforms to Codable")
    func jsInputUsernameConformsToCodable() throws {
        let username = JSInputUsername(username: "test@example.com")
        let encoded = try JSONEncoder().encode(username)
        let decoded = try JSONDecoder().decode(JSInputUsername.self, from: encoded)

        #expect(decoded.username == username.username)
    }

    @Test("JSInputCredentials conforms to Codable")
    func jsInputCredentialsConformsToCodable() throws {
        let credentials = JSInputCredentials(username: "test@example.com", password: "password")
        let encoded = try JSONEncoder().encode(credentials)
        let decoded = try JSONDecoder().decode(JSInputCredentials.self, from: encoded)

        #expect(decoded.username == credentials.username)
        #expect(decoded.password == credentials.password)
    }

    @Test("JSInputUsername conforms to Sendable")
    func jsInputUsernameConformsToSendable() throws {
        let username = JSInputUsername(username: "test@example.com")

        // Sendable conformance is compile-time checked
        // This test verifies it can be used in async contexts
        Task {
            _ = username.username
        }

        #expect(username.username == "test@example.com")
    }

    @Test("JSInputCredentials conforms to Sendable")
    func jsInputCredentialsConformsToSendable() throws {
        let credentials = JSInputCredentials(username: "test@example.com", password: "password")

        // Sendable conformance is compile-time checked
        // This test verifies it can be used in async contexts
        Task {
            _ = credentials.username
            _ = credentials.password
        }

        #expect(credentials.username == "test@example.com")
    }

    // MARK: - Edge Cases

    @Test("JSInputUsername with very long username")
    func jsInputUsernameVeryLong() throws {
        let longUsername = String(repeating: "a", count: 1000) + "@example.com"
        let username = JSInputUsername(username: longUsername)
        let json = try username.toJSON()

        #expect(json != nil)
        #expect(json?.contains(longUsername) == true)
    }

    @Test("JSInputCredentials with very long password")
    func jsInputCredentialsVeryLongPassword() throws {
        let longPassword = String(repeating: "x", count: 1000)
        let credentials = JSInputCredentials(username: "test@example.com", password: longPassword)
        let json = try credentials.toJSON()

        #expect(json != nil)
        #expect(json?.contains(longPassword) == true)
    }

    @Test("JSInputCredentials with newlines in password")
    func jsInputCredentialsWithNewlines() throws {
        let credentials = JSInputCredentials(username: "test@example.com", password: "pass\nword")
        let json = try credentials.toJSON()

        #expect(json != nil)
        // Newlines should be escaped in JSON
        #expect(json?.contains("\\n") == true)
    }

    @Test("JSInputUsername with quotes in username")
    func jsInputUsernameWithQuotes() throws {
        let username = JSInputUsername(username: "test\"user@example.com")
        let json = try username.toJSON()

        #expect(json != nil)
        // Quotes should be escaped in JSON
        #expect(json?.contains("\\\"") == true)
    }

    @Test("JSInputCredentials with backslashes")
    func jsInputCredentialsWithBackslashes() throws {
        let credentials = JSInputCredentials(username: "test\\user@example.com", password: "pass\\word")
        let json = try credentials.toJSON()

        #expect(json != nil)
        // Backslashes should be escaped in JSON
        #expect(json?.contains("\\\\") == true)
    }
}
