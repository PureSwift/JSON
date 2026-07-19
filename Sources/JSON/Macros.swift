//
//  Macros.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/19/26.
//

#if !hasFeature(Embedded) && SWIFTPM_ENABLE_MACROS
/// Generates `JSONEncodable` and `JSONDecodable` conformance for a struct or class.
///
/// Adds a `CodingKeys` enum with a case for each stored property, an
/// `init(from:)` initializer and an `encode()` method. Optional properties are
/// encoded with `encodeIfPresent(_:forKey:)` and decoded with
/// `decodeIfPresent(_:forKey:)`, so absent keys and `null` decode as `nil` and
/// `nil` values are omitted from the encoded object.
/// For structs the generated members live in an extension, so the compiler's
/// memberwise initializer is preserved. For classes the members are generated
/// in the type itself, since designated initializers cannot be declared in
/// extensions.
@attached(member, names: named(CodingKeys), named(init(from:)), named(encode))
@attached(extension, conformances: JSONEncodable, JSONDecodable, names: named(CodingKeys), named(init(from:)), named(encode))
public macro JSONCodable() = #externalMacro(
    module: "JSONMacros",
    type: "JSONCodableMacro"
)
#endif
