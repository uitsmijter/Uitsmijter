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
    try configure(app)
    try await app.execute()
    try await app.asyncShutdown()
} catch {
    app.logger.report(error: error)
    try? await app.asyncShutdown()
    throw error
}
