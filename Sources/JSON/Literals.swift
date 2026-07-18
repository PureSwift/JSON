//
//  Literals.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

extension JSON: ExpressibleByNilLiteral {

    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSON: ExpressibleByBooleanLiteral {

    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSON: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSON: ExpressibleByIntegerLiteral {

    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }
}

extension JSON: ExpressibleByFloatLiteral {

    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSON: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: JSON...) {
        self = .array(elements)
    }
}

extension JSON: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, JSON)...) {
        var object = [String: JSON](minimumCapacity: elements.count)
        for (key, value) in elements {
            object[key] = value
        }
        self = .object(object)
    }
}

// MARK: - CustomStringConvertible

extension JSON: CustomStringConvertible {

    public var description: String {
        toString()
    }
}

extension JSON: CustomDebugStringConvertible {

    public var debugDescription: String {
        toString(options: [.prettyPrint, .sortedKeys])
    }
}
