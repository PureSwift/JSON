//
//  Error.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/19/26.
//

/// An error produced during macro expansion.
public enum MacroError: Error, CustomStringConvertible {

    /// The macro can only be attached to a struct or class.
    case invalidType

    /// A stored property requires an explicit type annotation.
    case missingTypeAnnotation(String)

    public var description: String {
        switch self {
        case .invalidType:
            return "@JSONCodable can only be attached to a struct or class"
        case let .missingTypeAnnotation(property):
            return "Stored property '\(property)' requires an explicit type annotation"
        }
    }
}
