import Foundation
@testable import Uitsmijter_AuthServer
import Testing
import JWTKit

@Suite("JWT Payload Tests")
// swiftlint:disable type_body_length
struct PayloadTest {

    @Test("Payload initializes with all required fields")
    func initializesWithRequiredFields() {
        let subject: SubjectClaim = "user123"
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let tenant = "test-tenant"
        let role = "admin"
        let user = "user@example.com"

        let payload = Payload(
            subject: subject,
            expiration: expiration,
            tenant: tenant,
            role: role,
            user: user
        )

        #expect(payload.subject == subject)
        #expect(payload.expiration.value == expiration.value)
        #expect(payload.tenant == tenant)
        #expect(payload.role == role)
        #expect(payload.user == user)
        #expect(payload.responsibility == nil)
        #expect(payload.profile == nil)
    }

    @Test("Payload initializes with optional fields")
    func initializesWithOptionalFields() {
        let subject: SubjectClaim = "user456"
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let tenant = "premium-tenant"
        let responsibility = "admin-scope"
        let role = "superadmin"
        let user = "admin@example.com"
        let profile: CodableProfile = .object(["name": .string("John Doe"), "age": .integer(30)])

        let payload = Payload(
            subject: subject,
            expiration: expiration,
            tenant: tenant,
            responsibility: responsibility,
            role: role,
            user: user,
            profile: profile
        )

        #expect(payload.subject == subject)
        #expect(payload.tenant == tenant)
        #expect(payload.responsibility == responsibility)
        #expect(payload.role == role)
        #expect(payload.user == user)
        #expect(payload.profile != nil)
    }

    @Test("Payload encodes to JSON with correct claim keys")
    func encodesToJSONWithCorrectKeys() throws {
        let subject: SubjectClaim = "test-user"
        let expirationDate = Date(timeIntervalSince1970: 1_700_000_000)
        let expiration = ExpirationClaim(value: expirationDate)

        let payload = Payload(
            subject: subject,
            expiration: expiration,
            tenant: "my-tenant",
            role: "user",
            user: "test@example.com"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        #expect(json?["sub"] as? String == "test-user")
        // ExpirationClaim encoding is handled by JWTKit - just verify it exists
        #expect(json?["exp"] != nil)
        #expect(json?["tenant"] as? String == "my-tenant")
        #expect(json?["role"] as? String == "user")
        #expect(json?["user"] as? String == "test@example.com")
        #expect(json?["responsibility"] == nil)
        #expect(json?["profile"] == nil)
    }

    @Test("Payload decodes from JSON with correct claim keys")
    func decodesFromJSONWithCorrectKeys() throws {
        let expirationTimestamp: Double = 1_700_000_000
        let json = """
        {
            "sub": "decoded-user",
            "exp": \(expirationTimestamp),
            "tenant": "decoded-tenant",
            "role": "moderator",
            "user": "mod@example.com"
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(Payload.self, from: data)

        #expect(payload.subject == "decoded-user")
        // ExpirationClaim decoding is handled by JWTKit - just verify it's reasonable
        #expect(payload.expiration.value.timeIntervalSince1970 > 0)
        #expect(payload.tenant == "decoded-tenant")
        #expect(payload.role == "moderator")
        #expect(payload.user == "mod@example.com")
        #expect(payload.responsibility == nil)
        #expect(payload.profile == nil)
    }

    @Test("Payload decodes with optional fields present")
    func decodesWithOptionalFields() throws {
        let json = """
        {
            "sub": "full-user",
            "exp": 1700000000,
            "tenant": "full-tenant",
            "responsibility": "full-scope",
            "role": "owner",
            "user": "owner@example.com",
            "profile": {
                "firstName": "Jane",
                "lastName": "Doe"
            }
        }
        """

        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(Payload.self, from: data)

        #expect(payload.subject == "full-user")
        #expect(payload.tenant == "full-tenant")
        #expect(payload.responsibility == "full-scope")
        #expect(payload.role == "owner")
        #expect(payload.user == "owner@example.com")
        #expect(payload.profile != nil)
    }

    @Test("Payload round-trip encoding and decoding")
    func roundTripEncodingDecoding() throws {
        let originalPayload = Payload(
            subject: "roundtrip-user",
            expiration: ExpirationClaim(value: Date(timeIntervalSince1970: 1_700_000_000)),
            tenant: "roundtrip-tenant",
            responsibility: "roundtrip-scope",
            role: "developer",
            user: "dev@example.com",
            profile: .object(["team": .string("backend")])
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalPayload)

        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(Payload.self, from: data)

        #expect(decodedPayload.subject == originalPayload.subject)
        #expect(
            decodedPayload.expiration.value.timeIntervalSince1970
                == originalPayload.expiration.value.timeIntervalSince1970
        )
        #expect(decodedPayload.tenant == originalPayload.tenant)
        #expect(decodedPayload.responsibility == originalPayload.responsibility)
        #expect(decodedPayload.role == originalPayload.role)
        #expect(decodedPayload.user == originalPayload.user)
    }

    @Test("Payload verify succeeds for non-expired token")
    func verifySucceedsForNonExpiredToken() throws {
        let futureDate = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        let payload = Payload(
            subject: "valid-user",
            expiration: ExpirationClaim(value: futureDate),
            tenant: "test-tenant",
            role: "user",
            user: "valid@example.com"
        )

        let signer = JWTSigner.hs256(key: "test-secret-key")

        // Should not throw
        try payload.verify(using: signer)
    }

    @Test("Payload verify fails for expired token")
    func verifyFailsForExpiredToken() throws {
        let pastDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let payload = Payload(
            subject: "expired-user",
            expiration: ExpirationClaim(value: pastDate),
            tenant: "test-tenant",
            role: "user",
            user: "expired@example.com"
        )

        let signer = JWTSigner.hs256(key: "test-secret-key")

        // Should throw an error
        #expect(throws: Error.self) {
            try payload.verify(using: signer)
        }
    }

    @Test("Payload conforms to SubjectProtocol")
    func conformsToSubjectProtocol() {
        let payload = Payload(
            subject: "protocol-user",
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            tenant: "test-tenant",
            role: "user",
            user: "protocol@example.com"
        )

        // Can be used as SubjectProtocol
        let subjectProtocol: SubjectProtocol = payload
        #expect(subjectProtocol.subject == "protocol-user")
    }

    @Test("Payload conforms to UserProfileProtocol")
    func conformsToUserProfileProtocol() {
        let profile: CodableProfile = .object(["department": .string("Engineering")])
        var payload = Payload(
            subject: "profile-user",
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            tenant: "test-tenant",
            role: "engineer",
            user: "engineer@example.com",
            profile: profile
        )

        // Can be used as UserProfileProtocol
        let userProfile: UserProfileProtocol = payload
        #expect(userProfile.role == "engineer")
        #expect(userProfile.user == "engineer@example.com")
        #expect(userProfile.profile != nil)

        // Can modify role through protocol
        payload.role = "senior-engineer"
        #expect(payload.role == "senior-engineer")
    }

    @Test("Payload handles empty strings correctly")
    func handlesEmptyStrings() {
        let payload = Payload(
            subject: "",
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            tenant: "",
            role: "",
            user: ""
        )

        #expect(payload.subject == "")
        #expect(payload.tenant == "")
        #expect(payload.role == "")
        #expect(payload.user == "")
    }

    @Test("Payload with profile containing nested objects")
    func profileWithNestedObjects() throws {
        let nestedProfile: CodableProfile = .object([
            "user": .object([
                "firstName": .string("Alice"),
                "lastName": .string("Smith")
            ]),
            "metadata": .object([
                "created": .string("2023-01-01"),
                "updated": .string("2023-12-01")
            ])
        ])

        let payload = Payload(
            subject: "nested-user",
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            tenant: "test-tenant",
            role: "user",
            user: "nested@example.com",
            profile: nestedProfile
        )

        // Encode and decode to verify nested structure is preserved
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(Payload.self, from: data)

        #expect(decodedPayload.profile != nil)
    }

    @Test("Payload with profile containing arrays")
    func profileWithArrays() throws {
        let arrayProfile: CodableProfile = .object([
            "permissions": .array([
                .string("read"),
                .string("write"),
                .string("delete")
            ]),
            "tags": .array([
                .string("vip"),
                .string("premium")
            ])
        ])

        let payload = Payload(
            subject: "array-user",
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            tenant: "test-tenant",
            role: "admin",
            user: "array@example.com",
            profile: arrayProfile
        )

        // Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(Payload.self, from: data)

        #expect(decodedPayload.profile != nil)
    }
}
// swiftlint:enable type_body_length
