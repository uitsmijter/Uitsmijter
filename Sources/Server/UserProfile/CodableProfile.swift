import Foundation

/// A `CodableProfile` represents a JSON-Profile that is provided by the backend system and in any form of valid json.
/// Implementation of a dynamic typed data struct.
enum CodableProfile {
    case double(Double)
    case integer(Int)
    case string(String)
    case boolean(Bool)
    case null
    indirect case array([CodableProfile])
    indirect case object([String: CodableProfile])
}

/// A CodableProfile is Encodable
extension CodableProfile: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

/// A CodableProfile is Decodable
extension CodableProfile: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int.self) {
            self = .integer(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        if let value = try? container.decode([CodableProfile].self) {
            self = .array(value)
            return
        }

        if let value = try? container.decode([String: CodableProfile].self) {
            self = .object(value)
            return
        }

        if let container = try? decoder.singleValueContainer(), container.decodeNil() {
            self = .null
            return
        }

        throw DecodingError.dataCorrupted(
                .init(
                        codingPath: container.codingPath,
                        debugDescription: "Cannot decode profile"
                )
        )
    }
}

/// Direct accessible values in the `CodableProfile`
/// - Note:
///     ```swift
///     let name = json.object?["name"]?.string
///     ```
extension CodableProfile {
    var int: Int? {
        guard case let .integer(value) = self else {
            return nil
        }
        return value
    }

    var double: Double? {
        guard case let .double(value) = self else {
            return nil
        }
        return value
    }

    var string: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }

    var isNil: Bool {
        guard case .null = self else {
            return false
        }
        return true
    }

    var bool: Bool? {
        guard case let .boolean(value) = self else {
            return nil
        }
        return value
    }

    var array: [CodableProfile]? {
        guard case let .array(value) = self else {
            return nil
        }
        return value
    }

    var object: [String: CodableProfile]? {
        guard case let .object(value) = self else {
            return nil
        }
        return value
    }
}
