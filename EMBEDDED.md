# Plan: Embedded Swift support (full rewrite)

Goal: rewrite this library as a **single implementation** that compiles under both regular Swift
and **Embedded Swift** (`-enable-experimental-feature Embedded`). All Swift 3-era code is removed.

References:
- [orlandos-nl/swift-json](https://github.com/orlandos-nl/swift-json) — Embedded-safe parser design
  (single-allocation, `UnsafeBufferPointer`-based, no Foundation in the hot path).
- **CoreModel** (`~/Developer/CoreModel`) — the API model for this branch: consumers hand-write
  `encode()` / `init(from:)` against typed keyed helpers; macros come later (phase 2, separate
  branch, mirroring CoreModel's `SWIFTPM_ENABLE_MACROS` opt-in).
- [PureSwift/swift-embedded-foundation](https://github.com/PureSwift/swift-embedded-foundation)
  (`FoundationEmbedded` module) — Foundation types (`Data`, `Date`, `UUID`, `URL`, `Decimal`) for
  platforms with no Foundation at all.

## Decisions (locked in)

1. **One target, one implementation.** No `_JSONCore`/umbrella split, no traits. A single `JSON`
   target whose sources compile unmodified in both modes; the only conditionals are the Foundation
   import block and the `#if hasFeature(Embedded)` `CodingKey` shim.
2. **Delete all existing sources.** The Swift 3 parser/serializer/`Any` bridge/`JSONEncodable`
   protocols in `Sources/` are removed, as are the `Xcode/` project and the pre-tools-version
   manifest.
3. **Foundation import pattern** (used at the top of every file that needs Foundation types):
   ```swift
   #if canImport(FoundationEssentials)
   import FoundationEssentials
   #elseif canImport(Foundation)
   import Foundation
   #else
   import FoundationEmbedded
   #endif
   ```
   `swift-embedded-foundation` is a package dependency; on platforms that have
   Foundation/FoundationEssentials its module is simply never imported.
4. **Hand-written coding, CoreModel-style.** No `Codable` (unavailable under Embedded). Consumers
   implement `encode()` and `init(from:)` themselves using typed keyed helpers. Phase 2 adds
   `@JSONCodable`-style macros on another branch to generate these.

## Target API

### Value type

```swift
/// A JSON value.
public enum JSON: Equatable, Hashable, Sendable {
    case null
    case bool(Bool)
    case string(String)
    case integer(Int64)
    case double(Double)
    case array([JSON])
    case object([String: JSON])
}
```

Plus (all Embedded-safe):
- `ExpressibleBy{Nil,Boolean,Integer,Float,String,Array,Dictionary}Literal` — literal element type
  is `JSON` itself, never a protocol existential.
- Accessors: `var boolValue: Bool?`, `stringValue`, `integerValue`, `doubleValue`, `arrayValue`,
  `objectValue`; `subscript(key: String) -> JSON?`, `subscript(index: Int) -> JSON?`.
- `CustomStringConvertible` via the serializer.

### Errors — typed throws everywhere

`any Error` existentials don't exist under Embedded, so every `throws` is typed
(CoreModel's `throws(ModelDataDecodingError)` pattern):

```swift
public struct JSONParseError: Error, Equatable, Sendable { offset, reason }
public enum JSONDecodeError: Error, Sendable {
    case keyNotFound(String)
    case typeMismatch(key: String)   // no metatype/String(describing:) under Embedded
    case invalidValue(JSON)
}
```

Note from CoreModel ([Decodable.swift:85](../CoreModel/Sources/CoreModel/Decodable.swift)): avoid
`map`/`rethrows` closures inside typed-throws functions — the `rethrows` overload erases to
`any Error` and won't compile under Embedded. Use explicit loops.

### Coding protocols (mirroring CoreModel's `AttributeEncodable`/`AttributeDecodable`)

```swift
/// A type that can be converted to a JSON value.
public protocol JSONEncodable {
    func encode() -> JSON
}

/// A type that can be initialized from a JSON value.
public protocol JSONDecodable {
    init(from json: JSON) throws(JSONDecodeError)
}
```

Conformances provided for `Bool`, `String`, all `Int`/`UInt` widths, `Float`, `Double`,
`Optional<Wrapped: ...>`, `Array<Element: ...>`, `Dictionary<String, Value: ...>`, and
`RawRepresentable where RawValue: ...` (enum support). Foundation types (`Date`, `UUID`, `URL`,
`Data`, `Decimal`) get conformances using the resolved Foundation module — e.g. `UUID` encodes as
`.string(uuidString)`, `Date` as ISO-8601 or epoch double, `Data` as base64 string.

### Keyed container helpers (the CoreModel `ModelData.encode/decode` analog)

```swift
public extension JSON {
    /// Keyed accessors for hand-written `encode()` / `init(from:)`.
    mutating func encode<T, K>(_ value: T, forKey key: K) where T: JSONEncodable, K: CodingKey
    func decode<T, K>(_ type: T.Type, forKey key: K) throws(JSONDecodeError) -> T
        where T: JSONDecodable, K: CodingKey
    func decodeIfPresent<T, K>(_ type: T.Type, forKey key: K) throws(JSONDecodeError) -> T?
        where T: JSONDecodable, K: CodingKey
}
```

`CodingKey` is `Swift.CodingKey` normally; under Embedded it's a drop-in shim protocol copied from
CoreModel's [EmbeddedCodingKey.swift](../CoreModel/Sources/CoreModel/Embedded/EmbeddedCodingKey.swift)
(`#if hasFeature(Embedded)`), with default implementations for `RawRepresentable, RawValue == String`.
Consumers declare `enum CodingKeys: String, CodingKey` in both modes — identical source.

### Consumer example (what a hand-written conformance looks like)

```swift
struct Person: JSONEncodable, JSONDecodable {

    let id: UUID
    var name: String
    var age: UInt8?

    enum CodingKeys: String, CodingKey { case id, name, age }

    init(from json: JSON) throws(JSONDecodeError) {
        self.id = try json.decode(UUID.self, forKey: CodingKeys.id)
        self.name = try json.decode(String.self, forKey: CodingKeys.name)
        self.age = try json.decodeIfPresent(UInt8.self, forKey: CodingKeys.age)
    }

    func encode() -> JSON {
        var json = JSON.object([:])
        json.encode(id, forKey: CodingKeys.id)
        json.encode(name, forKey: CodingKeys.name)
        json.encode(age, forKey: CodingKeys.age)
        return json
    }
}
```

### Parser / Serializer

Rewritten (informed by the old implementation and IkigaJSON), Embedded-safe:

- `JSON.init(parsing bytes: some Collection<UInt8>) throws(JSONParseError)` — core entry point,
  `UnsafeBufferPointer` fast path internally; `JSON.init(parsing string: String) throws(JSONParseError)`.
- `Data` overloads always available via the Foundation import pattern (all three modules provide `Data`).
- `func toString(options:) -> String`, `func toData(options:) -> Data`; serializer writes into a
  generic `TextOutputStream` / `[UInt8]` accumulator. Options: `prettyPrint`, `sortedKeys` (needed
  for deterministic output on Embedded where dictionary order varies).
- No `Darwin.C`/`Glibc` imports unless number formatting requires them; prefer pure-Swift
  `Int64`/`Double` formatting to stay freestanding-safe.

## Package.swift

```swift
// swift-tools-version: 6.1  (6.x — final version chosen to match toolchain features needed)
import PackageDescription

let package = Package(
    name: "JSON",
    products: [
        .library(name: "JSON", targets: ["JSON"])
    ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/swift-embedded-foundation.git", branch: "master")
    ],
    targets: [
        .target(
            name: "JSON",
            dependencies: [
                .product(name: "FoundationEmbedded", package: "swift-embedded-foundation")
            ]
        ),
        .testTarget(name: "JSONTests", dependencies: ["JSON"])
    ],
    swiftLanguageModes: [.v6]
)
```

(If depending on `FoundationEmbedded` unconditionally causes issues on Foundation platforms, fall
back to CoreModel's approach of environment-gated manifest mutation — but unconditional should be
fine since the module is inert when unused.)

## Steps

1. **Clean slate** — delete `Sources/*.swift`, `Xcode/`, old manifest cruft; new `Package.swift`
   as above; `Sources/JSON/` + `Tests/JSONTests/` layout.
2. **`JSON` enum** — value type, literals, accessors, subscripts, `Equatable`/`Hashable`/`Sendable`.
3. **Errors** — `JSONParseError`, `JSONDecodeError` with typed throws.
4. **Coding protocols** — `JSONEncodable`/`JSONDecodable` + all primitive/Foundation conformances;
   Embedded `CodingKey` shim; keyed `encode(_:forKey:)`/`decode(_:forKey:)` helpers.
5. **Parser** — byte-level recursive-descent parser, typed throws, `[UInt8]`/`String`/`Data` entry
   points.
6. **Serializer** — compact + pretty printing, `sortedKeys`, `String`/`Data`/`[UInt8]` output.
7. **Tests** — round-trip, parser conformance (RFC 8259 cases), hand-written codable fixture like
   CoreModel's `EmbeddedFixture.swift`; an `#if hasFeature(Embedded)` fixture to force generic
   specialization of the decode path.
8. **Embedded CI** — `build-embedded.sh` compiling the target with
   `-enable-experimental-feature Embedded -wmo` (wasm or ARM none triple, matching CoreModel's CI);
   GitHub Actions job for embedded build + regular `swift test`.
9. **README** — usage, hand-written coding example, Embedded notes.

## Phase 2 (separate branch, out of scope here)

`@JSONCodable` macro generating `CodingKeys`, `init(from:)`, and `encode()` — following CoreModel's
`Macros.swift` + `SWIFTPM_ENABLE_MACROS` opt-in structure so Embedded builds can disable
swift-syntax.
