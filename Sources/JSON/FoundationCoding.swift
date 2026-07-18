//
//  FoundationCoding.swift
//  JSON
//
//  `JSONEncodable` / `JSONDecodable` conformances for Foundation value types.
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#else
import FoundationEmbedded
#endif

// MARK: - UUID

extension UUID: JSONEncodable {

    public func encode() -> JSON { .string(uuidString) }
}

extension UUID: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .string(string) = json,
              let value = UUID(uuidString: string)
            else { throw .invalidValue(json) }
        self = value
    }
}

// MARK: - URL

extension URL: JSONEncodable {

    public func encode() -> JSON { .string(absoluteString) }
}

extension URL: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .string(string) = json,
              let value = URL(string: string)
            else { throw .invalidValue(json) }
        self = value
    }
}

// MARK: - Date

extension Date: JSONEncodable {

    /// Encodes the date as seconds since the Unix epoch.
    public func encode() -> JSON { .double(timeIntervalSince1970) }
}

extension Date: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard let value = json.doubleValue else {
            throw .invalidValue(json)
        }
        self = Date(timeIntervalSince1970: value)
    }
}

// MARK: - Data

extension Data: JSONEncodable {

    /// Encodes the data as a Base64 string.
    public func encode() -> JSON { .string(Base64.encode(self)) }
}

extension Data: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .string(string) = json,
              let bytes = Base64.decode(string)
            else { throw .invalidValue(json) }
        self = Data(bytes)
    }
}

// MARK: - Decimal

extension Decimal: JSONEncodable {

    /// Encodes the decimal as a string to avoid loss of precision.
    public func encode() -> JSON { .string(description) }
}

extension Decimal: JSONDecodable {

    public init(from json: JSON) throws(JSONDecodeError) {
        guard case let .string(string) = json,
              let value = Decimal(string: string)
            else { throw .invalidValue(json) }
        self = value
    }
}
