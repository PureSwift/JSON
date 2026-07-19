//
//  JSONCodableMacroTests.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/19/26.
//

#if SWIFTPM_ENABLE_MACROS
import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import JSON

@JSONCodable
struct Product: Equatable {

    let id: UUID

    var name: String

    var price: Double

    var quantity: UInt16?

    var website: URL?

    var tags: [String]
}

@JSONCodable
final class Counter {

    var count: Int

    init(count: Int) {
        self.count = count
    }
}

@Suite
struct JSONCodableMacroRuntimeTests {

    @Test func roundTrip() throws {
        let product = Product(
            id: UUID(),
            name: "Widget",
            price: 9.99,
            quantity: 100,
            website: URL(string: "https://example.com"),
            tags: ["new", "sale"]
        )
        let json = product.encode()
        let string = json.toString(options: [.sortedKeys])
        let parsed = try JSON(parsing: string)
        let decoded = try Product(from: parsed)
        #expect(decoded == product)
    }

    @Test func optionals() throws {
        let product = Product(
            id: UUID(),
            name: "Widget",
            price: 0,
            quantity: nil,
            website: nil,
            tags: []
        )
        let json = product.encode()
        // nil values are omitted, not encoded as null
        #expect(json["quantity"] == nil)
        #expect(json["website"] == nil)
        let decoded = try Product(from: json)
        #expect(decoded == product)
    }

    @Test func codingKeys() {
        #expect(Product.CodingKeys.id.stringValue == "id")
        #expect(Product.CodingKeys.name.stringValue == "name")
        #expect(Product.CodingKeys.quantity.stringValue == "quantity")
        #expect(Product.CodingKeys(stringValue: "price") == .price)
    }

    @Test func decodeErrors() {
        // missing required key
        #expect(throws: JSONDecodeError.self) {
            try Product(from: .object([:]))
        }
        // wrong type for required key
        let json = JSON.object([
            "id": .string(UUID().uuidString),
            "name": .integer(1),
            "price": .double(1),
            "tags": .array([])
        ])
        #expect(throws: JSONDecodeError.self) {
            try Product(from: json)
        }
    }

    @Test func reference() throws {
        let counter = Counter(count: 42)
        let json = counter.encode()
        #expect(json == .object(["count": .integer(42)]))
        let decoded = try Counter(from: json)
        #expect(decoded.count == 42)
    }
}
#endif
