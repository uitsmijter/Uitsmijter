import Foundation
import Vapor

struct CrossOriginResourceSharing {

    /// CORS Configuration
    static let Configuration = CORSMiddleware.Configuration(
            allowedOrigin: .all,
            allowedMethods: [
                .GET,
                .POST,
                .HEAD,
                .OPTIONS
            ],
            allowedHeaders: [
                .host,
                .accept,
                .acceptLanguage,
                .authorization,
                .accessControlRequestHeaders, .accessControlAllowCredentials,
                .setCookie,
                .cookie,
                .forwarded,
                .contentType,
                .location,
                .origin,
                .referer,
                .userAgent,
                .accessControlAllowOrigin,
                .xRequestedWith,
                .xForwardedFor,
                .xForwardedHost,
                .xForwardedProto
            ]
    )

}
