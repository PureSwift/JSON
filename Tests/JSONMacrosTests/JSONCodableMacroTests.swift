//
//  JSONCodableMacroTests.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/19/26.
//

// Macro expansion tests depend on the swift-syntax host tooling and only run
// where the test suite is executed (macOS and Linux); other CI platforms
// cross-compile the package and never run `swift test`. Android also matches
// `os(Linux)` when cross-compiling, so it is excluded explicitly.
#if (os(macOS) || os(Linux)) && !os(Android)

import XCTest
import SwiftSyntax
import SwiftParser
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import JSONMacros

final class JSONCodableMacroTests: XCTestCase {

    func testStructExpansion() throws {
        let (node, declaration) = try parse("""
        @JSONCodable
        struct Person {
            let id: UUID
            var name: String
            var age: UInt8?
        }
        """)
        let context = BasicMacroExpansionContext()
        // struct members are generated in the extension, not the type,
        // to preserve the compiler's memberwise initializer
        let members = try JSONCodableMacro.expansion(of: node, providingMembersOf: declaration, in: context)
        XCTAssertEqual(members.count, 0)
        let extensions = try expandExtension(of: node, attachedTo: declaration, in: context)
        XCTAssertEqual(extensions.count, 1)
        let source = extensions.map { $0.description }.joined(separator: "\n")
        XCTAssert(source.contains("extension Person: JSONEncodable, JSONDecodable"))
        XCTAssert(source.contains("public enum CodingKeys: String, CodingKey {"))
        XCTAssert(source.contains("case id"))
        XCTAssert(source.contains("case name"))
        XCTAssert(source.contains("case age"))
        XCTAssert(source.contains("public init(from json: JSON) throws(JSONDecodeError) {"))
        XCTAssert(source.contains("self.id = try json.decode(UUID.self, forKey: CodingKeys.id)"))
        XCTAssert(source.contains("self.name = try json.decode(String.self, forKey: CodingKeys.name)"))
        XCTAssert(source.contains("self.age = try json.decodeIfPresent(UInt8.self, forKey: CodingKeys.age)"))
        XCTAssert(source.contains("public func encode() -> JSON {"))
        XCTAssert(source.contains("json.encode(self.id, forKey: CodingKeys.id)"))
        XCTAssert(source.contains("json.encode(self.name, forKey: CodingKeys.name)"))
        XCTAssert(source.contains("json.encodeIfPresent(self.age, forKey: CodingKeys.age)"))
    }

    func testClassExpansion() throws {
        let (node, declaration) = try parse("""
        @JSONCodable
        final class Counter {
            var count: Int
        }
        """)
        let context = BasicMacroExpansionContext()
        // class members are generated in the type, since designated
        // initializers cannot be declared in extensions
        let members = try JSONCodableMacro.expansion(of: node, providingMembersOf: declaration, in: context)
        XCTAssertEqual(members.count, 3)
        let source = members.map { $0.description }.joined(separator: "\n")
        XCTAssert(source.contains("public enum CodingKeys: String, CodingKey {"))
        XCTAssert(source.contains("public required init(from json: JSON) throws(JSONDecodeError) {"))
        XCTAssert(source.contains("self.count = try json.decode(Int.self, forKey: CodingKeys.count)"))
        // the extension only declares the conformances
        let extensions = try expandExtension(of: node, attachedTo: declaration, in: context)
        XCTAssertEqual(extensions.count, 1)
        let extensionSource = extensions.map { $0.description }.joined(separator: "\n")
        XCTAssert(extensionSource.contains("extension Counter: JSONEncodable, JSONDecodable"))
        XCTAssertFalse(extensionSource.contains("CodingKeys"))
    }

    func testOptionalSpellings() throws {
        let (node, declaration) = try parse("""
        @JSONCodable
        struct Value {
            var a: Int?
            var b: Optional<String>
        }
        """)
        let context = BasicMacroExpansionContext()
        let extensions = try expandExtension(of: node, attachedTo: declaration, in: context)
        let source = extensions.map { $0.description }.joined(separator: "\n")
        XCTAssert(source.contains("self.a = try json.decodeIfPresent(Int.self, forKey: CodingKeys.a)"))
        XCTAssert(source.contains("self.b = try json.decodeIfPresent(String.self, forKey: CodingKeys.b)"))
        XCTAssert(source.contains("json.encodeIfPresent(self.a, forKey: CodingKeys.a)"))
        XCTAssert(source.contains("json.encodeIfPresent(self.b, forKey: CodingKeys.b)"))
    }

    func testSkipsComputedAndStaticProperties() throws {
        let (node, declaration) = try parse("""
        @JSONCodable
        struct Person {
            static var kind: String { "person" }
            static let shared: Int = 0
            var name: String
            var uppercased: String { name.uppercased() }
            var explicit: Int {
                get { 1 }
                set { }
            }
            var observed: Int = 0 {
                didSet { }
            }
        }
        """)
        let context = BasicMacroExpansionContext()
        let extensions = try expandExtension(of: node, attachedTo: declaration, in: context)
        let source = extensions.map { $0.description }.joined(separator: "\n")
        XCTAssert(source.contains("case name"))
        XCTAssertFalse(source.contains("case kind"))
        XCTAssertFalse(source.contains("case shared"))
        XCTAssertFalse(source.contains("case uppercased"))
        XCTAssertFalse(source.contains("case explicit"))
        // didSet observers are stored properties
        XCTAssert(source.contains("case observed"))
    }

    func testEnumThrows() throws {
        let (node, declaration) = try parse("""
        @JSONCodable
        enum Role {
            case admin
        }
        """)
        let context = BasicMacroExpansionContext()
        XCTAssertThrowsError(
            try JSONCodableMacro.expansion(of: node, providingMembersOf: declaration, in: context)
        ) { error in
            XCTAssert(error is MacroError)
        }
        XCTAssertThrowsError(
            try expandExtension(of: node, attachedTo: declaration, in: context)
        ) { error in
            XCTAssert(error is MacroError)
        }
    }

    func testMissingTypeAnnotationThrows() throws {
        let (node, declaration) = try parse("""
        @JSONCodable
        struct Person {
            var age = 0
        }
        """)
        let context = BasicMacroExpansionContext()
        XCTAssertThrowsError(
            try expandExtension(of: node, attachedTo: declaration, in: context)
        ) { error in
            guard case let .missingTypeAnnotation(property)? = error as? MacroError else {
                return XCTFail("Expected missingTypeAnnotation, got \(error)")
            }
            XCTAssertEqual(property, "age")
        }
    }

    func testNoConformancesRequested() throws {
        let (node, declaration) = try parse("""
        @JSONCodable
        struct Person {
            var name: String
        }
        """)
        let context = BasicMacroExpansionContext()
        // struct: members are still generated even when the compiler
        // requests no conformances
        let extensions = try expandExtension(of: node, attachedTo: declaration, conformingTo: [], in: context)
        XCTAssertEqual(extensions.count, 1)
        let source = extensions.map { $0.description }.joined(separator: "\n")
        XCTAssertFalse(source.contains(": JSONEncodable"))
        XCTAssert(source.contains("public enum CodingKeys"))
        // class: nothing to generate in the extension
        let (classNode, classDeclaration) = try parse("""
        @JSONCodable
        final class Counter {
            var count: Int
        }
        """)
        let empty = try expandExtension(of: classNode, attachedTo: classDeclaration, conformingTo: [], in: context)
        XCTAssertEqual(empty.count, 0)
    }

    func testMacroErrorDescriptions() {
        XCTAssertFalse(MacroError.invalidType.description.isEmpty)
        XCTAssertFalse(MacroError.missingTypeAnnotation("age").description.isEmpty)
    }
}

// MARK: - Helpers

private extension JSONCodableMacroTests {

    /// Parse source containing a single attributed type declaration, returning the
    /// macro attribute node and the declaration group it is attached to.
    func parse(_ source: String) throws -> (AttributeSyntax, any DeclGroupSyntax) {
        let file = Parser.parse(source: source)
        guard let decl = file.statements.first?.item.as(DeclSyntax.self) else {
            throw MacroError.invalidType
        }
        let group: (any DeclGroupSyntax)?
        let attributes: AttributeListSyntax
        if let structDecl = decl.as(StructDeclSyntax.self) {
            group = structDecl
            attributes = structDecl.attributes
        } else if let classDecl = decl.as(ClassDeclSyntax.self) {
            group = classDecl
            attributes = classDecl.attributes
        } else if let enumDecl = decl.as(EnumDeclSyntax.self) {
            group = enumDecl
            attributes = enumDecl.attributes
        } else {
            group = nil
            attributes = []
        }
        guard let group, let node = attributes.first?.as(AttributeSyntax.self) else {
            throw MacroError.invalidType
        }
        return (node, group)
    }

    func expandExtension(
        of node: AttributeSyntax,
        attachedTo declaration: any DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax] = [
            TypeSyntax(stringLiteral: "JSONEncodable"),
            TypeSyntax(stringLiteral: "JSONDecodable")
        ],
        in context: BasicMacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let typeName: String
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            typeName = structDecl.name.text
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            typeName = classDecl.name.text
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            typeName = enumDecl.name.text
        } else {
            typeName = "Unknown"
        }
        return try JSONCodableMacro.expansion(
            of: node,
            attachedTo: declaration,
            providingExtensionsOf: TypeSyntax(stringLiteral: typeName),
            conformingTo: protocols,
            in: context
        )
    }
}

#endif
