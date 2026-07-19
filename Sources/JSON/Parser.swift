//
//  Parser.swift
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

// MARK: - Parsing

public extension JSON {

    /// Parses JSON from UTF-8 encoded text.
    ///
    /// Zero-copy when the collection provides contiguous storage
    /// (e.g. `[UInt8]`, `ArraySlice<UInt8>`); otherwise the bytes
    /// are copied into a contiguous buffer once.
    init<C>(parsing bytes: C, options: ParsingOptions = .init()) throws(JSONParseError) where C: Collection, C.Element == UInt8 {
        // - Note: The closure-based buffer accessors are `rethrows`, which
        //   erases the typed `throws(JSONParseError)` to `any Error` and
        //   cannot compile under Embedded Swift. Capture a `Result` inside
        //   the closure and rethrow outside with the typed `Result.get()`.
        self = try Parser.parse(contiguous: bytes, options: options).get()
    }

    /// Parses JSON from a string.
    init(parsing string: String, options: ParsingOptions = .init()) throws(JSONParseError) {
        var string = string
        let result = string.withUTF8 { buffer in
            Parser.parse(buffer, options: options)
        }
        self = try result.get()
    }

    /// Parses JSON from UTF-8 encoded data.
    init(parsing data: Data, options: ParsingOptions = .init()) throws(JSONParseError) {
        self = try Parser.parse(contiguous: data, options: options).get()
    }
}

// MARK: - ParsingOptions

public extension JSON {

    /// Options for parsing JSON text.
    struct ParsingOptions: Equatable, Hashable, Sendable {

        /// The maximum nesting depth of arrays and objects.
        public var maximumDepth: Int

        public init(maximumDepth: Int = 512) {
            self.maximumDepth = maximumDepth
        }
    }
}

// MARK: - Parser

internal extension JSON {

    /// Recursive descent JSON parser operating on a contiguous UTF-8 buffer.
    ///
    /// The cursor addresses the caller's storage directly — the input is not
    /// copied. `~Copyable` guarantees the cursor state cannot be accidentally
    /// duplicated. The pointer is only valid for the lifetime of the buffer
    /// access closure in the entry points above.
    struct Parser: ~Copyable {

        let base: UnsafePointer<UInt8>

        let count: Int

        let options: ParsingOptions

        var index: Int = 0

        var depth: Int = 0

        init(base: UnsafePointer<UInt8>, count: Int, options: ParsingOptions) {
            self.base = base
            self.count = count
            self.options = options
        }
    }
}

internal extension JSON.Parser {

    /// Parses from any byte collection, borrowing contiguous storage when
    /// available and copying into a contiguous buffer once otherwise.
    static func parse<C>(contiguous bytes: C, options: JSON.ParsingOptions) -> Result<JSON, JSONParseError> where C: Collection, C.Element == UInt8 {
        bytes.withContiguousStorageIfAvailable { buffer in
            parse(buffer, options: options)
        } ?? Array(bytes).withUnsafeBufferPointer { buffer in
            parse(buffer, options: options)
        }
    }

    /// Parses a complete document from the buffer, capturing the typed error.
    static func parse(_ buffer: UnsafeBufferPointer<UInt8>, options: JSON.ParsingOptions) -> Result<JSON, JSONParseError> {
        guard let base = buffer.baseAddress, buffer.count > 0 else {
            return .failure(JSONParseError(offset: 0, reason: .emptyInput))
        }
        var parser = JSON.Parser(base: base, count: buffer.count, options: options)
        do {
            return .success(try parser.parse())
        } catch {
            return .failure(error)
        }
    }

    mutating func parse() throws(JSONParseError) -> JSON {
        skipWhitespace()
        guard index < count else {
            throw JSONParseError(offset: 0, reason: .emptyInput)
        }
        let value = try parseValue()
        skipWhitespace()
        guard index == count else {
            throw error(.unexpectedCharacter(base[index]))
        }
        return value
    }

    func error(_ reason: JSONParseError.Reason) -> JSONParseError {
        JSONParseError(offset: index, reason: reason)
    }

    mutating func skipWhitespace() {
        while index < count {
            switch base[index] {
            case 0x20, 0x09, 0x0A, 0x0D: // space, tab, newline, carriage return
                index += 1
            default:
                return
            }
        }
    }

    mutating func parseValue() throws(JSONParseError) -> JSON {
        guard index < count else {
            throw error(.unexpectedEndOfInput)
        }
        switch base[index] {
        case UInt8(ascii: "{"):
            return try parseObject()
        case UInt8(ascii: "["):
            return try parseArray()
        case UInt8(ascii: "\""):
            return .string(try parseString())
        case UInt8(ascii: "t"):
            try parseLiteral("true")
            return .bool(true)
        case UInt8(ascii: "f"):
            try parseLiteral("false")
            return .bool(false)
        case UInt8(ascii: "n"):
            try parseLiteral("null")
            return .null
        case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return try parseNumber()
        default:
            throw error(.unexpectedCharacter(base[index]))
        }
    }

    mutating func parseLiteral(_ literal: StaticString) throws(JSONParseError) {
        let expected = literal.utf8Start
        for offset in 0 ..< literal.utf8CodeUnitCount {
            guard index < count else {
                throw error(.unexpectedEndOfInput)
            }
            guard base[index] == expected[offset] else {
                throw error(.invalidLiteral)
            }
            index += 1
        }
    }

    // MARK: Object

    mutating func parseObject() throws(JSONParseError) -> JSON {
        assert(base[index] == UInt8(ascii: "{"))
        try incrementDepth()
        defer { depth -= 1 }
        index += 1 // consume '{'
        var object = [String: JSON]()
        skipWhitespace()
        guard index < count else {
            throw error(.unexpectedEndOfInput)
        }
        // empty object
        if base[index] == UInt8(ascii: "}") {
            index += 1
            return .object(object)
        }
        repeat {
            skipWhitespace()
            let key = try parseString()
            skipWhitespace()
            guard index < count else {
                throw error(.unexpectedEndOfInput)
            }
            guard base[index] == UInt8(ascii: ":") else {
                throw error(.unexpectedCharacter(base[index]))
            }
            index += 1 // consume ':'
            skipWhitespace()
            object[key] = try parseValue()
            skipWhitespace()
            guard index < count else {
                throw error(.unexpectedEndOfInput)
            }
            switch base[index] {
            case UInt8(ascii: ","):
                index += 1
                continue
            case UInt8(ascii: "}"):
                index += 1
                return .object(object)
            default:
                throw error(.unexpectedCharacter(base[index]))
            }
        } while true
    }

    // MARK: Array

    mutating func parseArray() throws(JSONParseError) -> JSON {
        assert(base[index] == UInt8(ascii: "["))
        try incrementDepth()
        defer { depth -= 1 }
        index += 1 // consume '['
        var array = [JSON]()
        skipWhitespace()
        guard index < count else {
            throw error(.unexpectedEndOfInput)
        }
        // empty array
        if base[index] == UInt8(ascii: "]") {
            index += 1
            return .array(array)
        }
        repeat {
            skipWhitespace()
            array.append(try parseValue())
            skipWhitespace()
            guard index < count else {
                throw error(.unexpectedEndOfInput)
            }
            switch base[index] {
            case UInt8(ascii: ","):
                index += 1
                continue
            case UInt8(ascii: "]"):
                index += 1
                return .array(array)
            default:
                throw error(.unexpectedCharacter(base[index]))
            }
        } while true
    }

    mutating func incrementDepth() throws(JSONParseError) {
        depth += 1
        guard depth <= options.maximumDepth else {
            throw error(.maximumDepthExceeded)
        }
    }

    // MARK: String

    mutating func parseString() throws(JSONParseError) -> String {
        guard index < count else {
            throw error(.unexpectedEndOfInput)
        }
        guard base[index] == UInt8(ascii: "\"") else {
            throw error(.unexpectedCharacter(base[index]))
        }
        index += 1 // consume '"'
        var utf8 = [UInt8]()
        while index < count {
            let byte = base[index]
            switch byte {
            case UInt8(ascii: "\""):
                index += 1
                return String(decoding: utf8, as: UTF8.self)
            case UInt8(ascii: "\\"):
                index += 1
                try parseEscape(into: &utf8)
            case 0x00 ... 0x1F:
                // unescaped control characters are invalid
                throw error(.unexpectedCharacter(byte))
            default:
                utf8.append(byte)
                index += 1
            }
        }
        throw error(.unexpectedEndOfInput)
    }

    mutating func parseEscape(into utf8: inout [UInt8]) throws(JSONParseError) {
        guard index < count else {
            throw error(.unexpectedEndOfInput)
        }
        let byte = base[index]
        index += 1
        switch byte {
        case UInt8(ascii: "\""):
            utf8.append(UInt8(ascii: "\""))
        case UInt8(ascii: "\\"):
            utf8.append(UInt8(ascii: "\\"))
        case UInt8(ascii: "/"):
            utf8.append(UInt8(ascii: "/"))
        case UInt8(ascii: "b"):
            utf8.append(0x08)
        case UInt8(ascii: "f"):
            utf8.append(0x0C)
        case UInt8(ascii: "n"):
            utf8.append(0x0A)
        case UInt8(ascii: "r"):
            utf8.append(0x0D)
        case UInt8(ascii: "t"):
            utf8.append(0x09)
        case UInt8(ascii: "u"):
            var scalar = try parseUnicodeEscape()
            // surrogate pair
            if scalar >= 0xD800, scalar <= 0xDBFF {
                guard index + 1 < count,
                      base[index] == UInt8(ascii: "\\"),
                      base[index + 1] == UInt8(ascii: "u")
                    else { throw error(.invalidUnicode) }
                index += 2 // consume "\u"
                let low = try parseUnicodeEscape()
                guard low >= 0xDC00, low <= 0xDFFF else {
                    throw error(.invalidUnicode)
                }
                scalar = 0x10000 + ((scalar - 0xD800) << 10) + (low - 0xDC00)
            } else if scalar >= 0xDC00, scalar <= 0xDFFF {
                // unpaired low surrogate
                throw error(.invalidUnicode)
            }
            appendScalar(scalar, into: &utf8)
        default:
            throw error(.invalidEscape)
        }
    }

    /// Parses 4 hexadecimal digits following `\u`.
    mutating func parseUnicodeEscape() throws(JSONParseError) -> UInt32 {
        var value: UInt32 = 0
        for _ in 0 ..< 4 {
            guard index < count else {
                throw error(.unexpectedEndOfInput)
            }
            let byte = base[index]
            let digit: UInt32
            switch byte {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                digit = UInt32(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a") ... UInt8(ascii: "f"):
                digit = UInt32(byte - UInt8(ascii: "a")) + 10
            case UInt8(ascii: "A") ... UInt8(ascii: "F"):
                digit = UInt32(byte - UInt8(ascii: "A")) + 10
            default:
                throw error(.invalidUnicode)
            }
            value = (value << 4) | digit
            index += 1
        }
        return value
    }

    /// Encodes a Unicode scalar value as UTF-8.
    func appendScalar(_ scalar: UInt32, into utf8: inout [UInt8]) {
        switch scalar {
        case 0x00 ... 0x7F:
            utf8.append(UInt8(scalar))
        case 0x80 ... 0x7FF:
            utf8.append(UInt8(0xC0 | (scalar >> 6)))
            utf8.append(UInt8(0x80 | (scalar & 0x3F)))
        case 0x800 ... 0xFFFF:
            utf8.append(UInt8(0xE0 | (scalar >> 12)))
            utf8.append(UInt8(0x80 | ((scalar >> 6) & 0x3F)))
            utf8.append(UInt8(0x80 | (scalar & 0x3F)))
        default:
            utf8.append(UInt8(0xF0 | (scalar >> 18)))
            utf8.append(UInt8(0x80 | ((scalar >> 12) & 0x3F)))
            utf8.append(UInt8(0x80 | ((scalar >> 6) & 0x3F)))
            utf8.append(UInt8(0x80 | (scalar & 0x3F)))
        }
    }

    // MARK: Number

    mutating func parseNumber() throws(JSONParseError) -> JSON {
        let start = index
        var isDouble = false
        // sign
        if base[index] == UInt8(ascii: "-") {
            index += 1
        }
        // integer part
        guard index < count else {
            throw error(.unexpectedEndOfInput)
        }
        switch base[index] {
        case UInt8(ascii: "0"):
            index += 1
            // leading zeros are invalid
            if index < count, case UInt8(ascii: "0") ... UInt8(ascii: "9") = base[index] {
                throw error(.invalidNumber)
            }
        case UInt8(ascii: "1") ... UInt8(ascii: "9"):
            repeat {
                index += 1
            } while index < count && isDigit(base[index])
        default:
            throw error(.invalidNumber)
        }
        // fraction
        if index < count, base[index] == UInt8(ascii: ".") {
            isDouble = true
            index += 1
            guard index < count, isDigit(base[index]) else {
                throw error(.invalidNumber)
            }
            repeat {
                index += 1
            } while index < count && isDigit(base[index])
        }
        // exponent
        if index < count, base[index] == UInt8(ascii: "e") || base[index] == UInt8(ascii: "E") {
            isDouble = true
            index += 1
            if index < count, base[index] == UInt8(ascii: "+") || base[index] == UInt8(ascii: "-") {
                index += 1
            }
            guard index < count, isDigit(base[index]) else {
                throw error(.invalidNumber)
            }
            repeat {
                index += 1
            } while index < count && isDigit(base[index])
        }
        let string = String(decoding: UnsafeBufferPointer(start: base + start, count: index - start), as: UTF8.self)
        if isDouble == false, let integer = Int64(string) {
            return .integer(integer)
        }
        // fall back to floating point for out-of-range integers
        #if hasFeature(Embedded)
        // `Double.init(String)` requires `_swift_stdlib_strtod_clocale`, which
        // the Embedded Swift runtime does not provide, so convert manually.
        return .double(JSON.double(parsing: bytes[start ..< index]))
        #else
        // - Note: Defensive guard; every number accepted by the grammar checks
        //   above parses as `Double` (huge magnitudes clamp to infinity), so
        //   this path is unreachable in practice and excluded from coverage.
        guard let double = Double(string) else {
            throw error(.invalidNumber)
        }
        return .double(double)
        #endif
    }

    func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }
}

extension JSON {

    /// Converts grammar-validated JSON number bytes to a `Double` without
    /// `Double.init(String)`, which is unavailable under Embedded Swift.
    ///
    /// Accumulates up to 19 significant digits into a `UInt64` mantissa and
    /// scales by the decimal exponent, so the result can differ from the
    /// correctly rounded value by ~1 ulp for long inputs.
    @_spi(Testing)
    public static func double<S>(parsing bytes: S) -> Double where S: Sequence, S.Element == UInt8 {
        var mantissa: UInt64 = 0
        var digitCount = 0
        var exponent = 0
        var explicitExponent = 0
        var negative = false
        var negativeExponent = false
        var inFraction = false
        var inExponent = false
        for byte in bytes {
            switch byte {
            case UInt8(ascii: "-"):
                if inExponent { negativeExponent = true } else { negative = true }
            case UInt8(ascii: "+"):
                break
            case UInt8(ascii: "."):
                inFraction = true
            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                inExponent = true
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                let digit = Int(byte - UInt8(ascii: "0"))
                if inExponent {
                    // clamp to avoid overflow; ±9999 already saturates Double
                    explicitExponent = min(explicitExponent * 10 + digit, 9999)
                } else if digitCount < 19, mantissa != 0 || digit != 0 {
                    mantissa = mantissa * 10 + UInt64(digit)
                    digitCount += 1
                    if inFraction { exponent -= 1 }
                } else if mantissa == 0 {
                    // leading zeros contribute only to the exponent
                    if inFraction { exponent -= 1 }
                } else if inFraction == false {
                    // digits beyond the mantissa's precision shift the exponent
                    exponent += 1
                }
            default:
                break
            }
        }
        exponent += negativeExponent ? -explicitExponent : explicitExponent
        var value = Double(mantissa)
        // scale by 10^exponent via exponentiation by squaring;
        // overflow and underflow saturate to infinity and zero
        var power = 10.0
        var remaining = exponent.magnitude
        while remaining > 0 {
            if remaining & 1 == 1 {
                value = exponent < 0 ? value / power : value * power
            }
            remaining >>= 1
            if remaining > 0 { power *= power }
        }
        return negative ? -value : value
    }
}
