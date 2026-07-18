//
//  Encodable.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

// MARK: - JSONEncodable

/// A type that can be converted to a JSON value.
public protocol JSONEncodable {

    /// Encodes the receiver into JSON.
    func encode() -> JSON
}

// MARK: - Keyed Encoding

public extension JSON {

    /// Encodes a value into the receiver for the specified key.
    ///
    /// If the receiver is not a JSON object, it is replaced with one.
    mutating func encode<T, K>(_ value: T, forKey key: K) where T: JSONEncodable, K: CodingKey {
        var object = self.objectValue ?? [:]
        object[key.stringValue] = value.encode()
        self = .object(object)
    }

    /// Encodes a value into the receiver for the specified key, omitting `nil`.
    ///
    /// Unlike `encode(_:forKey:)` with an optional value, no `null` is written
    /// when the value is `nil`.
    mutating func encodeIfPresent<T, K>(_ value: T?, forKey key: K) where T: JSONEncodable, K: CodingKey {
        guard let value else { return }
        encode(value, forKey: key)
    }
}

// MARK: - Default Conformances

extension JSON: JSONEncodable {

    public func encode() -> JSON { self }
}

extension Optional: JSONEncodable where Wrapped: JSONEncodable {

    public func encode() -> JSON {
        switch self {
        case .none:
            return .null
        case let .some(wrapped):
            return wrapped.encode()
        }
    }
}

extension JSONEncodable where Self: RawRepresentable, RawValue: JSONEncodable {

    public func encode() -> JSON {
        rawValue.encode()
    }
}

extension Bool: JSONEncodable {

    public func encode() -> JSON { .bool(self) }
}

extension String: JSONEncodable {

    public func encode() -> JSON { .string(self) }
}

extension Int: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension Int8: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension Int16: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension Int32: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension Int64: JSONEncodable {

    public func encode() -> JSON { .integer(self) }
}

extension UInt: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension UInt8: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension UInt16: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension UInt32: JSONEncodable {

    public func encode() -> JSON { .integer(numericCast(self)) }
}

extension UInt64: JSONEncodable {

    public func encode() -> JSON { .integer(Int64(clamping: self)) }
}

extension Float: JSONEncodable {

    public func encode() -> JSON { .double(Double(self)) }
}

extension Double: JSONEncodable {

    public func encode() -> JSON { .double(self) }
}

extension Array: JSONEncodable where Element: JSONEncodable {

    public func encode() -> JSON {
        var values = [JSON]()
        values.reserveCapacity(count)
        for element in self {
            values.append(element.encode())
        }
        return .array(values)
    }
}

extension Dictionary: JSONEncodable where Key == String, Value: JSONEncodable {

    public func encode() -> JSON {
        var object = [String: JSON](minimumCapacity: count)
        for (key, value) in self {
            object[key] = value.encode()
        }
        return .object(object)
    }
}
