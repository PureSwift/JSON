//
//  Decodable.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

// MARK: - JSONDecodable

/// A type that can be initialized from a JSON value.
public protocol JSONDecodable {

    /// Decodes the receiver from JSON.
    init(from json: JSON) throws(JSONDecodeError)
}

// MARK: - Keyed Decoding

public extension JSON {

    /// Decodes a value of the specified type for the specified key.
    func decode<T, K>(_ type: T.Type, forKey key: K) throws(JSONDecodeError) -> T where T: JSONDecodable, K: CodingKey {
        guard case let .object(object) = self,
              let value = object[key.stringValue]
            else { throw .keyNotFound(key.stringValue) }
        do {
            return try T.init(from: value)
        } catch {
            throw .typeMismatch(key.stringValue, value)
        }
    }

    /// Decodes a value of the specified type for the specified key,
    /// returning `nil` if the key is missing or the value is `null`.
    func decodeIfPresent<T, K>(_ type: T.Type, forKey key: K) throws(JSONDecodeError) -> T? where T: JSONDecodable, K: CodingKey {
        guard case let .object(object) = self,
              let value = object[key.stringValue],
              value.isNull == false
            else { return nil }
        do {
            return try T.init(from: value)
        } catch {
            throw .typeMismatch(key.stringValue, value)
        }
    }
}

// MARK: - Default Conformances

extension JSON: JSONDecodable {

    public init(from json: JSON) {
        self = json
    }
}

extension Optional: JSONDecodable where Wrapped: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        switch json {
        case .null:
            self = .none
        default:
            self = .some(try Wrapped.init(from: json))
        }
    }
}

extension JSONDecodable where Self: RawRepresentable, RawValue: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        let rawValue = try RawValue.init(from: json)
        guard let value = Self.init(rawValue: rawValue) else {
            throw .invalidValue(json)
        }
        self = value
    }
}

extension Bool: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .bool(value) = json else {
            throw .invalidValue(json)
        }
        self = value
    }
}

extension String: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .string(value) = json else {
            throw .invalidValue(json)
        }
        self = value
    }
}

/// Decodes an integer from `.integer`, validating the value fits the destination type.
internal func decodeInteger<T: FixedWidthInteger>(_ type: T.Type, from json: JSON) throws(JSONDecodeError) -> T {
    guard case let .integer(value) = json else {
        throw .invalidValue(json)
    }
    guard let integer = T.init(exactly: value) else {
        throw .invalidValue(json)
    }
    return integer
}

extension Int: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(Int.self, from: json)
    }
}

extension Int8: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(Int8.self, from: json)
    }
}

extension Int16: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(Int16.self, from: json)
    }
}

extension Int32: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(Int32.self, from: json)
    }
}

extension Int64: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(Int64.self, from: json)
    }
}

extension UInt: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(UInt.self, from: json)
    }
}

extension UInt8: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(UInt8.self, from: json)
    }
}

extension UInt16: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(UInt16.self, from: json)
    }
}

extension UInt32: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(UInt32.self, from: json)
    }
}

extension UInt64: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        self = try decodeInteger(UInt64.self, from: json)
    }
}

extension Float: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard let value = json.doubleValue else {
            throw .invalidValue(json)
        }
        self = Float(value)
    }
}

extension Double: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard let value = json.doubleValue else {
            throw .invalidValue(json)
        }
        self = value
    }
}

extension Array: JSONDecodable where Element: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .array(values) = json else {
            throw .invalidValue(json)
        }
        // - Note: An explicit loop rather than `values.map`, because the
        //   `rethrows` closure overload erases the thrown error back to
        //   `any Error`, which cannot convert to the typed `throws` clause
        //   under Embedded Swift.
        var elements = [Element]()
        elements.reserveCapacity(values.count)
        for value in values {
            elements.append(try Element.init(from: value))
        }
        self = elements
    }
}

extension Dictionary: JSONDecodable where Key == String, Value: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .object(object) = json else {
            throw .invalidValue(json)
        }
        var dictionary = [String: Value](minimumCapacity: object.count)
        for (key, value) in object {
            dictionary[key] = try Value.init(from: value)
        }
        self = dictionary
    }
}
