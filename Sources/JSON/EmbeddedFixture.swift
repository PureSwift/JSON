//
//  EmbeddedFixture.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

// - Note: A concrete `JSONEncodable` / `JSONDecodable` conformance that only
//   exists under Embedded Swift. It forces the compiler to specialize the
//   generic keyed `encode(_:forKey:)` / `decode(_:forKey:)` paths for a real
//   conforming type — the exact instantiation the embedded CI job never
//   exercises through the test target. Without it, error-boxing regressions in
//   that path can silently reappear. Dead weight on non-Embedded builds, so it
//   is gated out entirely there.

#if hasFeature(Embedded)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#else
import FoundationEmbedded
#endif

private struct EmbeddedFixture: JSONEncodable, JSONDecodable {

    let id: UUID

    var name: String

    var age: UInt8?

    enum CodingKeys: String, CodingKey {

        case id
        case name
        case age
    }

    init(from json: JSON) throws(JSONDecodeError) {
        self.id = try json.decode(UUID.self, forKey: CodingKeys.id)
        self.name = try json.decode(String.self, forKey: CodingKeys.name)
        self.age = try json.decodeIfPresent(UInt8.self, forKey: CodingKeys.age)
    }

    func encode() -> JSON {
        var json = JSON.object([:])
        json.encode(id, forKey: CodingKeys.id)
        json.encode(name, forKey: CodingKeys.name)
        json.encodeIfPresent(age, forKey: CodingKeys.age)
        return json
    }
}

/// Forces specialization of the parse, serialize and coding paths.
internal func _embeddedFixture() throws(JSONDecodeError) -> String {
    let json = JSON.object([
        "id": .string(UUID().uuidString),
        "name": .string("Embedded"),
        "age": .integer(28)
    ])
    let fixture = try EmbeddedFixture(from: json)
    let encoded = fixture.encode()
    let string = encoded.toString(options: [.sortedKeys])
    let parsed = try? JSON(parsing: string)
    return (parsed ?? encoded).toString()
}

#endif
