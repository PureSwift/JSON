//
//  Serializer.swift
//  JSON
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

// MARK: - Serialization

public extension JSON {

    /// Serializes the JSON value as a string.
    ///
    /// The output strictly conforms to [RFC 8259](https://tools.ietf.org/html/rfc8259).
    func toString(options: SerializationOptions = []) -> String {
        var output = ""
        write(to: &output, options: options, indentation: 0)
        return output
    }

    /// Serializes the JSON value as UTF-8 encoded data.
    ///
    /// The output strictly conforms to [RFC 8259](https://tools.ietf.org/html/rfc8259).
    func toData(options: SerializationOptions = []) -> Data {
        Data(toString(options: options).utf8)
    }
}

// MARK: - SerializationOptions

public extension JSON {

    /// Options for serializing JSON values.
    struct SerializationOptions: OptionSet, Equatable, Hashable, Sendable {

        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Format the output with indentation for readability.
        public static var prettyPrint: SerializationOptions { .init(rawValue: 0b01) }

        /// Serialize object keys in lexicographic order for deterministic output.
        public static var sortedKeys: SerializationOptions { .init(rawValue: 0b10) }
    }
}

// MARK: - Implementation

internal extension JSON {

    func write(to output: inout String, options: SerializationOptions, indentation: Int) {
        switch self {
        case .null:
            output += "null"
        case let .bool(value):
            output += value ? "true" : "false"
        case let .integer(value):
            output += value.description
        case let .double(value):
            JSON.write(value, to: &output)
        case let .string(value):
            JSON.write(value, to: &output)
        case let .array(array):
            JSON.write(array, to: &output, options: options, indentation: indentation)
        case let .object(object):
            JSON.write(object, to: &output, options: options, indentation: indentation)
        }
    }

    static func write(_ value: Double, to output: inout String) {
        if let integer = Int64(exactly: value) {
            // avoid trailing ".0" for whole numbers
            output += integer.description
        } else if value.isFinite {
            output += value.description
        } else {
            // Infinity and NaN are not representable in JSON
            output += "null"
        }
    }

    static func write(_ string: String, to output: inout String) {
        let hexDigits: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
        output += "\""
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case UInt32(UInt8(ascii: "\"")):
                output += "\\\""
            case UInt32(UInt8(ascii: "\\")):
                output += "\\\\"
            case 0x08:
                output += "\\b"
            case 0x0C:
                output += "\\f"
            case 0x0A:
                output += "\\n"
            case 0x0D:
                output += "\\r"
            case 0x09:
                output += "\\t"
            case 0x00 ... 0x1F:
                output += "\\u00"
                output.append(hexDigits[Int(scalar.value >> 4)])
                output.append(hexDigits[Int(scalar.value & 0xF)])
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }

    static func write(_ array: [JSON], to output: inout String, options: SerializationOptions, indentation: Int) {
        guard array.isEmpty == false else {
            output += "[]"
            return
        }
        let prettyPrint = options.contains(.prettyPrint)
        output += "["
        for (index, value) in array.enumerated() {
            if index > 0 {
                output += ","
            }
            if prettyPrint {
                newline(to: &output, indentation: indentation + 1)
            }
            value.write(to: &output, options: options, indentation: indentation + 1)
        }
        if prettyPrint {
            newline(to: &output, indentation: indentation)
        }
        output += "]"
    }

    static func write(_ object: [String: JSON], to output: inout String, options: SerializationOptions, indentation: Int) {
        guard object.isEmpty == false else {
            output += "{}"
            return
        }
        let prettyPrint = options.contains(.prettyPrint)
        var keys = [String](object.keys)
        if options.contains(.sortedKeys) {
            keys.sort()
        }
        output += "{"
        for (index, key) in keys.enumerated() {
            if index > 0 {
                output += ","
            }
            if prettyPrint {
                newline(to: &output, indentation: indentation + 1)
            }
            write(key, to: &output)
            output += prettyPrint ? ": " : ":"
            object[key]?.write(to: &output, options: options, indentation: indentation + 1)
        }
        if prettyPrint {
            newline(to: &output, indentation: indentation)
        }
        output += "}"
    }

    static func newline(to output: inout String, indentation: Int) {
        output += "\n"
        for _ in 0 ..< indentation {
            output += "  "
        }
    }
}
