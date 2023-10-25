import Foundation
import JWTKit

enum TokenError: Error {
    case CALCULATE_TIME
    case NO_PAYLOAD
}

struct Token: ExpressibleByStringLiteral {

    typealias StringLiteralType = String
    let signers = JWTSigners()

    let expirationDate: Date
    let secondsToExpire: Int
    let payload: Payload
    let value: String

    init(stringLiteral value: Self.StringLiteralType) {
        self.value = value
        do {
            signers.use(jwt_signer)
            payload = try signers.verify(self.value, as: Payload.self)
            expirationDate = payload.expiration.value
            secondsToExpire = expirationDate.millisecondsSinceNow / 1000
        } catch {
            Log.error("Can not init a Token from value: \(value), because: \(error.localizedDescription)")
            payload = Payload(
                    subject: "ERROR",
                    expiration: ExpirationClaim(value: Date()),
                    tenant: "",
                    role: "",
                    user: ""
            )
            expirationDate = Date()
            secondsToExpire = 0
        }
    }

    init(tenant: Tenant, subject: SubjectClaim, userProfile: UserProfileProtocol) throws {
        let calendar = Calendar.current
        guard let expirationDate = calendar.date(
                byAdding: .hour,
                value: Constants.TOKEN.EXPIRATION_HOURS,
                to: Date()
        )
        else {
            throw TokenError.CALCULATE_TIME
        }
        self.expirationDate = expirationDate
        secondsToExpire = Constants.TOKEN.EXPIRATION_HOURS * 60 * 60

        payload = Payload(
                subject: subject,
                expiration: .init(value: expirationDate),
                tenant: tenant.name,
                role: userProfile.role,
                user: userProfile.user,
                profile: userProfile.profile
        )

        signers.use(jwt_signer)
        value = try signers.sign(payload)
    }
}
