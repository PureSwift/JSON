# JSON

Swift JSON library with [Embedded Swift](https://github.com/swiftlang/swift/blob/main/docs/EmbeddedSwift/UserManual.md) support.

A single implementation that compiles for regular Swift (macOS, Linux, iOS, WebAssembly) and Embedded Swift (bare-metal, `wasm-embedded`) with no `Foundation`, `Codable`, existentials, reflection or dynamic casts in the core.

## Usage

### JSON values

```swift
import JSON

// literals
let json: JSON = [
    "name": "Alsey",
    "age": 28,
    "admin": true,
    "tags": ["swift", "embedded"]
]

// accessors
json["name"]?.stringValue  // "Alsey"
json["tags"]?[0]           // .string("swift")
```

### Parsing and serialization

```swift
// parse from String, [UInt8] or Data
let value = try JSON(parsing: #"{"key": [1, 2.5, null]}"#)

// serialize
let compact = value.toString()                                  // {"key":[1,2.5,null]}
let pretty = value.toString(options: [.prettyPrint, .sortedKeys])
let data = value.toData()
```

Parsing throws typed errors (`throws(JSONParseError)`) with byte offset and reason.

### Encoding and decoding

Attach the `@JSONCodable` macro to a struct or class to generate `JSONEncodable` and `JSONDecodable` conformance from its stored properties:

```swift
@JSONCodable
struct Product {

    let id: UUID
    var name: String
    var price: Double
    var quantity: UInt16?
}

let product = try Product(from: JSON(parsing: string))
let string = product.encode().toString()
```

The macro generates a `CodingKeys` enum, `init(from:)` and `encode()`. Optional properties are omitted when `nil` and decode as `nil` when absent or `null`. For structs the members are generated in an extension, so the compiler's memberwise initializer is preserved.

Macros are enabled by default and require swift-syntax at build time; pass `SWIFTPM_ENABLE_MACROS=0` to build without them (required for Embedded Swift, where you hand-write the conformances instead).

Alternatively, conform your types to `JSONEncodable` and `JSONDecodable` with hand-written implementations:

```swift
struct Person: JSONEncodable, JSONDecodable {

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

let person = try Person(from: JSON(parsing: string))
let string = person.encode().toString()
```

Conformances are provided for `Bool`, `String`, all integer widths, `Float`, `Double`, `Optional`, `Array`, `Dictionary<String, _>`, `RawRepresentable` enums, and the Foundation types `UUID`, `URL`, `Date`, `Data` and `Decimal`.

## Embedded Swift

The same module builds unmodified under Embedded Swift:

- Typed `throws` everywhere — no `any Error` existentials.
- No `Codable` — under Embedded, a drop-in `CodingKey` protocol is provided; declare `enum CodingKeys: String, CodingKey` and the same source compiles in both modes.
- Foundation types are provided by [`swift-embedded-foundation`](https://github.com/PureSwift/swift-embedded-foundation) on platforms without `Foundation` or `FoundationEssentials`.

Build with the Embedded WebAssembly SDK:

```sh
swift sdk install https://download.swift.org/swift-6.3.3-release/wasm-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz
./build-embedded.sh
```

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/PureSwift/JSON.git", branch: "feature/embedded")
```
