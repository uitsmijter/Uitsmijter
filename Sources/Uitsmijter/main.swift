//
// Uitsmijter - Authentication Server
//

import Uitsmijter_AuthServer
import Vapor
import Logging
import Foundation

print("🍳 Starting Uitsmijter...")
try? FileHandle.standardOutput.synchronize()

let env = try Environment.detect()
let app = try await Application.make(env)

do {
    try await configure(app)
    try await app.execute()
    app.entityLoader?.shutdown()
    try await app.asyncShutdown()
} catch {
    app.logger.report(error: error)
    app.entityLoader?.shutdown()
    try? await app.asyncShutdown()
    throw error
}
