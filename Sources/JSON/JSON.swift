//
//  JSON.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

/// [JavaScript Object Notation](https://json.org) value.
public enum JSON: Equatable, Hashable, Sendable {

    /// JSON `null` value.
    case null

    /// JSON boolean value.
    case bool(Bool)

    /// JSON string value.
    case string(String)

    /// JSON number value with no fractional component.
    case integer(Int64)

    /// JSON floating point number value.
    case double(Double)

    /// JSON array of values.
    case array([JSON])

    /// JSON object.
    case object([String: JSON])
}

// MARK: - Accessors

public extension JSON {

    /// The boolean value if the receiver is `.bool`, otherwise `nil`.
    var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    /// The string value if the receiver is `.string`, otherwise `nil`.
    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    /// The integer value if the receiver is `.integer`, otherwise `nil`.
    var integerValue: Int64? {
        guard case let .integer(value) = self else { return nil }
        return value
    }

    /// The floating point value if the receiver is `.double` or `.integer`, otherwise `nil`.
    var doubleValue: Double? {
        switch self {
        case let .double(value):
            return value
        case let .integer(value):
            return Double(value)
        default:
            return nil
        }
    }

    /// The array value if the receiver is `.array`, otherwise `nil`.
    var arrayValue: [JSON]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    /// The object value if the receiver is `.object`, otherwise `nil`.
    var objectValue: [String: JSON]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    /// Whether the receiver is `.null`.
    var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }
}

// MARK: - Subscripts

public extension JSON {

    /// Access a value of a JSON object by key.
    subscript(key: String) -> JSON? {
        guard case let .object(object) = self else { return nil }
        return object[key]
    }

    /// Access an element of a JSON array by index.
    subscript(index: Int) -> JSON? {
        guard case let .array(array) = self,
              index >= 0, index < array.count
            else { return nil }
        return array[index]
    }
}
