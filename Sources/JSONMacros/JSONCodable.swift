//
//  JSONCodable.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/19/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@JSONCodable` macro
///
/// Generates `JSONEncodable` / `JSONDecodable` conformance with a `CodingKeys`
/// enum, `init(from:)` and `encode()` derived from the stored properties.
///
/// For structs the members are generated in an extension, so the compiler's
/// memberwise initializer is preserved. For classes the members are generated
/// in the type itself, since designated initializers cannot be declared in
/// extensions.
public struct JSONCodableMacro: MemberMacro, ExtensionMacro {

    // Add CodingKeys, init(from:) and encode() for classes
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
            throw MacroError.invalidType
        }
        // struct members are generated in the extension instead
        guard declaration.is(ClassDeclSyntax.self) else { return [] }
        let properties = try storedProperties(of: declaration)
        return [
            try codingKeysDeclarationSyntax(for: properties),
            try initDeclarationSyntax(for: properties, isClass: true),
            try encodeDeclarationSyntax(for: properties)
        ]
    }

    // Add protocol conformance, and the generated members for structs
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
            throw MacroError.invalidType
        }
        let members: [DeclSyntax]
        if declaration.is(StructDeclSyntax.self) {
            let properties = try storedProperties(of: declaration)
            members = [
                try codingKeysDeclarationSyntax(for: properties),
                try initDeclarationSyntax(for: properties, isClass: false),
                try encodeDeclarationSyntax(for: properties)
            ]
        } else {
            members = []
        }
        // only declare the conformances the compiler asks for, to avoid duplicates
        guard protocols.isEmpty == false || members.isEmpty == false else { return [] }
        let inheritance = protocols.isEmpty
            ? ""
            : ": " + protocols.map { $0.trimmedDescription }.joined(separator: ", ")
        var extensionDecl = try ExtensionDeclSyntax(
            "extension \(type.trimmed)\(raw: inheritance) { }"
        )
        extensionDecl.memberBlock.members = MemberBlockItemListSyntax(
            members.map { MemberBlockItemSyntax(leadingTrivia: .newline, decl: $0) }
        )
        return [extensionDecl]
    }
}

extension JSONCodableMacro {

    /// A stored property of the attached declaration.
    struct StoredProperty {

        /// The property name.
        let name: String

        /// The property type with any `Optional` wrapping removed.
        let type: String

        /// Whether the property type is optional.
        let isOptional: Bool
    }

    /// Collects the stored properties of the declaration, in declaration order.
    static func storedProperties(of declaration: some DeclGroupSyntax) throws -> [StoredProperty] {
        var properties = [StoredProperty]()
        for member in declaration.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self)
                else { continue }
            // skip static properties
            guard varDecl.modifiers.contains(where: {
                $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
            }) == false else { continue }
            for binding in varDecl.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                    else { continue }
                // skip computed properties and observers with getters
                if let accessorBlock = binding.accessorBlock {
                    switch accessorBlock.accessors {
                    case .getter:
                        continue
                    case let .accessors(accessors):
                        // didSet/willSet observers are stored properties
                        let isComputed = accessors.contains {
                            switch $0.accessorSpecifier.tokenKind {
                            case .keyword(.get), .keyword(.set), .keyword(._read), .keyword(._modify):
                                return true
                            default:
                                return false
                            }
                        }
                        if isComputed { continue }
                    }
                }
                guard let typeSyntax = binding.typeAnnotation?.type else {
                    throw MacroError.missingTypeAnnotation(identifier)
                }
                let rawType = typeSyntax.trimmedDescription
                // strip Optional wrapping
                let type: String
                let isOptional: Bool
                if rawType.hasSuffix("?") {
                    type = String(rawType.dropLast())
                    isOptional = true
                } else if rawType.hasPrefix("Optional<"), rawType.hasSuffix(">") {
                    type = String(rawType.dropFirst("Optional<".count).dropLast())
                    isOptional = true
                } else {
                    type = rawType
                    isOptional = false
                }
                properties.append(StoredProperty(name: identifier, type: type, isOptional: isOptional))
            }
        }
        return properties
    }

    static func codingKeysDeclarationSyntax(for properties: [StoredProperty]) throws -> DeclSyntax {
        let cases = properties
            .map { "    case \($0.name)" }
            .joined(separator: "\n")
        let codingKeysDecl = """
        public enum CodingKeys: String, CodingKey {
        \(cases)
        }
        """
        return DeclSyntax(stringLiteral: codingKeysDecl)
    }

    static func initDeclarationSyntax(for properties: [StoredProperty], isClass: Bool) throws -> DeclSyntax {
        let lines = properties.map { property -> String in
            if property.isOptional {
                return "    self.\(property.name) = try json.decodeIfPresent(\(property.type).self, forKey: CodingKeys.\(property.name))"
            } else {
                return "    self.\(property.name) = try json.decode(\(property.type).self, forKey: CodingKeys.\(property.name))"
            }
        }
        // protocol initializer requirements must be `required` in classes
        let modifiers = isClass ? "public required" : "public"
        let initDecl = """
        \(modifiers) init(from json: JSON) throws(JSONDecodeError) {
        \(lines.joined(separator: "\n"))
        }
        """
        return DeclSyntax(stringLiteral: initDecl)
    }

    static func encodeDeclarationSyntax(for properties: [StoredProperty]) throws -> DeclSyntax {
        let lines = properties.map { property -> String in
            if property.isOptional {
                return "    json.encodeIfPresent(self.\(property.name), forKey: CodingKeys.\(property.name))"
            } else {
                return "    json.encode(self.\(property.name), forKey: CodingKeys.\(property.name))"
            }
        }
        let encodeDecl = """
        public func encode() -> JSON {
            var json = JSON.object([:])
        \(lines.joined(separator: "\n"))
            return json
        }
        """
        return DeclSyntax(stringLiteral: encodeDecl)
    }
}
