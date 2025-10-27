import Foundation

/// Protocol that have to be implemented in JavaScriptParameter implementations
///
public protocol JSInputParameterProtocol: Codable, Sendable {

}

/// global functions for every JavaScriptParameter implementations
///
extension JSInputParameterProtocol {

    /// Returns the JSInputParameter as a json string
    ///
    /// - Returns: Json string representing the JSInputParameter
    /// - Throws: An error when the encoding into a json string fails
    ///
    func toJSON() throws -> String? {
        try String(data: JSONEncoder().encode(self), encoding: .utf8)
    }
}
