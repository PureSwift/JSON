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
        var output = [UInt8]()
        output.reserveCapacity(256)
        write(to: &output, options: options, indentation: 0)
        return String(decoding: output, as: UTF8.self)
    }

    /// Serializes the JSON value as UTF-8 encoded data.
    ///
    /// The output strictly conforms to [RFC 8259](https://tools.ietf.org/html/rfc8259).
    func toData(options: SerializationOptions = []) -> Data {
        var output = [UInt8]()
        output.reserveCapacity(256)
        write(to: &output, options: options, indentation: 0)
        return Data(output)
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

    /// Lowercase hexadecimal digits for `\u00XX` control-character escapes.
    static let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)

    func write(to output: inout [UInt8], options: SerializationOptions, indentation: Int) {
        switch self {
        case .null:
            output.append(contentsOf: "null".utf8)
        case let .bool(value):
            output.append(contentsOf: (value ? "true" : "false").utf8)
        case let .integer(value):
            JSON.write(value, to: &output)
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

    // MARK: Number

    /// Writes the decimal representation of a signed integer.
    static func write(_ value: Int64, to output: inout [UInt8]) {
        let magnitude: UInt64
        if value < 0 {
            output.append(UInt8(ascii: "-"))
            // negate via unsigned to represent `Int64.min` without overflow
            magnitude = 0 &- UInt64(bitPattern: value)
        } else {
            magnitude = UInt64(bitPattern: value)
        }
        write(magnitude, to: &output)
    }

    /// Writes the decimal representation of an unsigned integer, most
    /// significant digit first, using a stack buffer (no heap allocation).
    static func write(_ magnitude: UInt64, to output: inout [UInt8]) {
        if magnitude == 0 {
            output.append(UInt8(ascii: "0"))
            return
        }
        // `UInt64.max` is 20 decimal digits.
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 20) { buffer in
            var index = 20
            var remaining = magnitude
            while remaining > 0 {
                index -= 1
                buffer[index] = UInt8(ascii: "0") &+ UInt8(remaining % 10)
                remaining /= 10
            }
            output.append(contentsOf: UnsafeBufferPointer(start: buffer.baseAddress! + index, count: 20 - index))
        }
    }

    static func write(_ value: Double, to output: inout [UInt8]) {
        if let integer = Int64(exactly: value) {
            // avoid trailing ".0" for whole numbers
            write(integer, to: &output)
        } else if value.isFinite {
            output.append(contentsOf: value.description.utf8)
        } else {
            // Infinity and NaN are not representable in JSON
            output.append(contentsOf: "null".utf8)
        }
    }

    // MARK: String

    static func write(_ string: String, to output: inout [UInt8]) {
        output.append(UInt8(ascii: "\""))
        var string = string
        string.withUTF8 { utf8 in
            guard let base = utf8.baseAddress else { return }
            let count = utf8.count
            var runStart = 0
            var index = 0
            while index < count {
                let byte = utf8[index]
                // only ASCII quote, backslash and control characters need
                // escaping; every UTF-8 continuation/lead byte is >= 0x80
                if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "\\") || byte < 0x20 {
                    if index > runStart {
                        output.append(contentsOf: UnsafeBufferPointer(start: base + runStart, count: index - runStart))
                    }
                    writeEscape(byte, to: &output)
                    index += 1
                    runStart = index
                } else {
                    index += 1
                }
            }
            if index > runStart {
                output.append(contentsOf: UnsafeBufferPointer(start: base + runStart, count: index - runStart))
            }
        }
        output.append(UInt8(ascii: "\""))
    }

    static func writeEscape(_ byte: UInt8, to output: inout [UInt8]) {
        output.append(UInt8(ascii: "\\"))
        switch byte {
        case UInt8(ascii: "\""):
            output.append(UInt8(ascii: "\""))
        case UInt8(ascii: "\\"):
            output.append(UInt8(ascii: "\\"))
        case 0x08:
            output.append(UInt8(ascii: "b"))
        case 0x0C:
            output.append(UInt8(ascii: "f"))
        case 0x0A:
            output.append(UInt8(ascii: "n"))
        case 0x0D:
            output.append(UInt8(ascii: "r"))
        case 0x09:
            output.append(UInt8(ascii: "t"))
        default:
            // other control characters: \u00XX
            output.append(UInt8(ascii: "u"))
            output.append(UInt8(ascii: "0"))
            output.append(UInt8(ascii: "0"))
            output.append(hexDigits[Int(byte >> 4)])
            output.append(hexDigits[Int(byte & 0xF)])
        }
    }

    // MARK: Containers

    static func write(_ array: [JSON], to output: inout [UInt8], options: SerializationOptions, indentation: Int) {
        guard array.isEmpty == false else {
            output.append(contentsOf: "[]".utf8)
            return
        }
        let prettyPrint = options.contains(.prettyPrint)
        output.append(UInt8(ascii: "["))
        for (index, value) in array.enumerated() {
            if index > 0 {
                output.append(UInt8(ascii: ","))
            }
            if prettyPrint {
                newline(to: &output, indentation: indentation + 1)
            }
            value.write(to: &output, options: options, indentation: indentation + 1)
        }
        if prettyPrint {
            newline(to: &output, indentation: indentation)
        }
        output.append(UInt8(ascii: "]"))
    }

    static func write(_ object: [String: JSON], to output: inout [UInt8], options: SerializationOptions, indentation: Int) {
        guard object.isEmpty == false else {
            output.append(contentsOf: "{}".utf8)
            return
        }
        let prettyPrint = options.contains(.prettyPrint)
        var keys = [String](object.keys)
        if options.contains(.sortedKeys) {
            keys.sort()
        }
        output.append(UInt8(ascii: "{"))
        for (index, key) in keys.enumerated() {
            if index > 0 {
                output.append(UInt8(ascii: ","))
            }
            if prettyPrint {
                newline(to: &output, indentation: indentation + 1)
            }
            write(key, to: &output)
            output.append(UInt8(ascii: ":"))
            if prettyPrint {
                output.append(UInt8(ascii: " "))
            }
            object[key]?.write(to: &output, options: options, indentation: indentation + 1)
        }
        if prettyPrint {
            newline(to: &output, indentation: indentation)
        }
        output.append(UInt8(ascii: "}"))
    }

    static func newline(to output: inout [UInt8], indentation: Int) {
        output.append(UInt8(ascii: "\n"))
        for _ in 0 ..< indentation {
            output.append(UInt8(ascii: " "))
            output.append(UInt8(ascii: " "))
        }
    }
}
