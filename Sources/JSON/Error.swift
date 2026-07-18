//
//  Error.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

// MARK: - Parse Error

/// An error produced while parsing JSON text.
public struct JSONParseError: Error, Equatable, Hashable, Sendable {

    /// The byte offset in the input at which the error occurred.
    public let offset: Int

    /// The reason parsing failed.
    public let reason: Reason

    public init(offset: Int, reason: Reason) {
        self.offset = offset
        self.reason = reason
    }
}

public extension JSONParseError {

    /// The reason parsing failed.
    enum Reason: Equatable, Hashable, Sendable {

        /// The input was empty.
        case emptyInput

        /// An unexpected byte was encountered.
        case unexpectedCharacter(UInt8)

        /// The input ended before a complete value was parsed.
        case unexpectedEndOfInput

        /// A `true`, `false` or `null` literal was malformed.
        case invalidLiteral

        /// A number was malformed or out of range.
        case invalidNumber

        /// A string contained an invalid escape sequence.
        case invalidEscape

        /// A string contained an invalid Unicode sequence.
        case invalidUnicode

        /// The maximum nesting depth was exceeded.
        case maximumDepthExceeded
    }
}

extension JSONParseError: CustomStringConvertible {

    public var description: String {
        "JSON parse error at offset \(offset): \(reason)"
    }
}

// MARK: - Decode Error

/// An error produced while decoding a value from JSON.
public enum JSONDecodeError: Error, Equatable, Hashable, Sendable {

    /// No value was associated with the specified key.
    case keyNotFound(String)

    /// The JSON value could not be converted to the requested type.
    case typeMismatch(String, JSON)

    /// The JSON value is invalid for the requested type.
    case invalidValue(JSON)
}

extension JSONDecodeError: CustomStringConvertible {

    public var description: String {
        switch self {
        case let .keyNotFound(key):
            return "No value associated with key \"\(key)\""
        case let .typeMismatch(key, value):
            return "Type mismatch for key \"\(key)\": \(value)"
        case let .invalidValue(value):
            return "Invalid value: \(value)"
        }
    }
}
