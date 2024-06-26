import Foundation
import Vapor

protocol DeviceRequestProtocol: Codable {
 
    var client_id: String { get }
}

struct DeviceRequest: DeviceRequestProtocol, ClientIdProtocol, ScopesProtocol {
    
    let grant_type: GrantTypes 

    var client_id: String
    
    var scope: String?

    init(client_id: String) {
        self.client_id = client_id
        grant_type = .device
    }

}

extension DeviceRequest: Content {

}

