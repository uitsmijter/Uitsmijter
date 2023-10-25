import Foundation
import Vapor

struct LocationContent {
    let location: String

    var url: URL? {
        URL(string: location)
    }
}

extension LocationContent: Content {

}
