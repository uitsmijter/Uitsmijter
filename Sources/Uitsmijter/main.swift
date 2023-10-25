//
// Uitsmijter - Authentication Server
//

import Server
import Vapor
import Logging

var env = try Environment.detect()
let app = Application(env)
defer {
    app.shutdown()
}

try configure(app)
try app.run()
