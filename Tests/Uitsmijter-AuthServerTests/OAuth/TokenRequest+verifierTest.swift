import Foundation
import Testing
import VaporTesting
import JWTKit
@testable import Uitsmijter_AuthServer

@Suite("Token Request Verifier Test")
@MainActor
struct TokenRequestVerifierTest {

    @Test("Verifier hash 1") func verifierHash1() {
        // https://referbruv.com/utilities/pkce-generator-online/
        // and tested with AppAuth-JS
        // swiftlint:disable:next line_length
        let value = "139EEDgEmydiFGhxFHlBMsBacEodEvavuPBhDjcqmJEND0pVfJOYNG4yxCDzRNZSNmToG7GB6fYetwmdcp3sw7rJOlOBSzSxfe7pAebxZmm5myUNXykMoU1w9ihhsZQt"
        let result = "9zkoYZ7h3xF9hnvrV_J9wgQl13HIajqzAV2EcJVseU8"
        let codeTokenRequest = CodeTokenRequest(
            grant_type: .authorization_code,
            client_id: "",
            client_secret: nil,
            scope: nil,
            code: "test",
            code_challenge_method: .sha256,
            code_verifier: value
        )
        #expect(codeTokenRequest.code_verifier == value)
        #expect(codeTokenRequest.code_challenge == result)
    }

    @Test("Verifier hash 2") func verifierHash2() {
        // https://referbruv.com/utilities/pkce-generator-online/
        // and tested with AppAuth-JS
        let value = "AAbb"
        let result = "wd0obL9-LvFPXDvrEMbPUlN6pgT-AqndJ1DpABlGmkQ"
        let codeTokenRequest = CodeTokenRequest(
            grant_type: .authorization_code,
            client_id: "",
            client_secret: nil,
            scope: nil,
            code: "test",
            code_challenge_method: .sha256,
            code_verifier: value
        )
        #expect(codeTokenRequest.code_verifier == value)
        #expect(codeTokenRequest.code_challenge == result)
    }
}
