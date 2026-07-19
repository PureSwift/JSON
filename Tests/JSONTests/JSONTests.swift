//
//  JSONTests.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import JSON

// MARK: - Value

@Suite
struct JSONValueTests {

    @Test func literals() {
        let json: JSON = [
            "null": nil,
            "bool": true,
            "int": 1,
            "double": 1.5,
            "string": "value",
            "array": [1, 2, 3]
        ]
        #expect(json["null"] == .null)
        #expect(json["bool"] == .bool(true))
        #expect(json["int"] == .integer(1))
        #expect(json["double"] == .double(1.5))
        #expect(json["string"] == .string("value"))
        #expect(json["array"] == .array([.integer(1), .integer(2), .integer(3)]))
        #expect(json["missing"] == nil)
    }

    @Test func accessors() {
        #expect(JSON.bool(true).boolValue == true)
        #expect(JSON.string("a").stringValue == "a")
        #expect(JSON.integer(1).integerValue == 1)
        #expect(JSON.double(1.5).doubleValue == 1.5)
        #expect(JSON.integer(2).doubleValue == 2.0)
        #expect(JSON.null.isNull)
        #expect(JSON.array([.null])[0] == .null)
        #expect(JSON.array([.null])[1] == nil)
        #expect(JSON.array([.null])[-1] == nil)
        #expect(JSON.bool(true).stringValue == nil)
        // wrong-type accessors return nil
        #expect(JSON.string("a").boolValue == nil)
        #expect(JSON.string("a").integerValue == nil)
        #expect(JSON.string("a").doubleValue == nil)
        #expect(JSON.string("a").arrayValue == nil)
        #expect(JSON.string("a").objectValue == nil)
        #expect(JSON.string("a").isNull == false)
        #expect(JSON.array([.null]).arrayValue == [.null])
        #expect(JSON.object(["a": .null]).objectValue == ["a": .null])
        // subscripts on wrong types
        #expect(JSON.string("a")["key"] == nil)
        #expect(JSON.string("a")[0] == nil)
    }
}

// MARK: - Parser

@Suite
struct JSONParserTests {

    @Test func object() throws {
        let json = try JSON(parsing: #"{"a": 1, "b": [true, false, null], "c": {"d": "e"}}"#)
        #expect(json["a"] == .integer(1))
        #expect(json["b"] == .array([.bool(true), .bool(false), .null]))
        #expect(json["c"]?["d"] == .string("e"))
    }

    @Test func numbers() throws {
        #expect(try JSON(parsing: "[0]") == .array([.integer(0)]))
        #expect(try JSON(parsing: "[-1]") == .array([.integer(-1)]))
        #expect(try JSON(parsing: "[9223372036854775807]") == .array([.integer(.max)]))
        #expect(try JSON(parsing: "[-9223372036854775808]") == .array([.integer(.min)]))
        #expect(try JSON(parsing: "[1.5]") == .array([.double(1.5)]))
        #expect(try JSON(parsing: "[-0.25]") == .array([.double(-0.25)]))
        #expect(try JSON(parsing: "[1e3]") == .array([.double(1000)]))
        #expect(try JSON(parsing: "[1.5E-1]") == .array([.double(0.15)]))
        // 64-bit overflow falls back to double
        #expect(try JSON(parsing: "[18446744073709551615]") == .array([.double(18446744073709551615)]))
    }

    @Test func strings() throws {
        #expect(try JSON(parsing: #""hello""#) == .string("hello"))
        #expect(try JSON(parsing: #""\" \\ \/ \b \f \n \r \t""#) == .string("\" \\ / \u{08} \u{0C} \n \r \t"))
        #expect(try JSON(parsing: #""A""#) == .string("A"))
        #expect(try JSON(parsing: #""é""#) == .string("é"))
        #expect(try JSON(parsing: #""❤""#) == .string("\u{2764}"))
        // surrogate pair
        #expect(try JSON(parsing: #""😀""#) == .string("😀"))
        // raw UTF-8 passthrough
        #expect(try JSON(parsing: #""héllo 😀""#) == .string("héllo 😀"))
    }

    @Test func inputTypes() throws {
        let string = #"{"a": [1]}"#
        let expected = JSON.object(["a": .array([.integer(1)])])
        #expect(try JSON(parsing: string) == expected)
        #expect(try JSON(parsing: Array(string.utf8)) == expected)
        #expect(try JSON(parsing: Data(string.utf8)) == expected)
        #expect(try JSON(parsing: string.utf8) == expected)
    }

    @Test func unicodeEscapes() throws {
        #expect(try JSON(parsing: #""\u0041""#) == .string("A"))                    // 1-byte UTF-8
        #expect(try JSON(parsing: #""\u00e9""#) == .string("\u{E9}"))               // 2-byte UTF-8
        #expect(try JSON(parsing: #""\u2764""#) == .string("\u{2764}"))             // 3-byte UTF-8
        #expect(try JSON(parsing: #""\uD83D\uDE00""#) == .string("\u{1F600}"))      // surrogate pair, 4-byte UTF-8
        #expect(try JSON(parsing: #""\u004A\u004a""#) == .string("JJ"))              // hex digit cases
    }

    @Test func fragments() throws {
        #expect(try JSON(parsing: "true") == .bool(true))
        #expect(try JSON(parsing: "false") == .bool(false))
        #expect(try JSON(parsing: "null") == .null)
        #expect(try JSON(parsing: "1") == .integer(1))
        #expect(try JSON(parsing: " 1 ") == .integer(1))
    }

    @Test func whitespace() throws {
        let json = try JSON(parsing: "\t{ \"a\" :\n [ 1 , 2 ] }\r\n")
        #expect(json == .object(["a": .array([.integer(1), .integer(2)])]))
    }

    @Test func empty() throws {
        #expect(try JSON(parsing: "{}") == .object([:]))
        #expect(try JSON(parsing: "[]") == .array([]))
    }

    @Test func invalidInput() {
        #expect(throws: JSONParseError(offset: 0, reason: .emptyInput)) {
            try JSON(parsing: "")
        }
        #expect(throws: JSONParseError(offset: 0, reason: .emptyInput)) {
            try JSON(parsing: "  ")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "{")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "[1,]")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: #"{"a" 1}"#)
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "tru")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "truthy")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "01")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "1.")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "1e")
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: #"["unterminated"#)
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: #""\x""#)
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: #""\uD83D""#) // unpaired high surrogate
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: #""\uDE00""#) // unpaired low surrogate
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "\"a\nb\"") // unescaped control character
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: "[1] [2]") // trailing content
        }
    }

    @Test func truncatedInput() {
        let truncated = [
            "-",                // sign without digits
            "tru",              // literal cut short
            "{",                // object without key
            "{\"a\"",           // object without colon
            "{\"a\":",          // object without value
            "{\"a\":1",         // object without closing brace
            "{\"a\":1,",        // object cut after comma
            "[",                // array without values
            "[1",               // array without closing bracket
            "[1,",              // array cut after comma
            "\"abc",            // unterminated string
            "\"abc\\",          // escape at end of input
            "\"\\u00",          // unicode escape cut short
            "\"\\uD83D",        // high surrogate at end of input
            "\"\\uD83D\\u"      // low surrogate cut short
        ]
        for string in truncated {
            #expect(throws: JSONParseError.self, "\(string)") {
                try JSON(parsing: string)
            }
        }
    }

    @Test func unexpectedCharacters() {
        let invalid = [
            "@",                // not a value
            "{1: 2}",           // non-string key
            "{\"a\": 1; }",     // bad object separator
            "[1; 2]",           // bad array separator
            "-x",               // sign without number
            "0.e1",             // fraction without digits
            "1e+",              // exponent without digits
            "\"\\uZZZZ\"",      // invalid hex digit
            "\"\\uD83D\\n\"",   // escape where low surrogate expected
            "\"\\uD83D\\u0041\"", // high surrogate followed by non-surrogate escape
            "nul1"              // corrupt literal
        ]
        for string in invalid {
            #expect(throws: JSONParseError.self, "\(string)") {
                try JSON(parsing: string)
            }
        }
    }

    @Test func maximumDepth() throws {
        let deep = String(repeating: "[", count: 100) + String(repeating: "]", count: 100)
        #expect(throws: Never.self) {
            try JSON(parsing: deep)
        }
        #expect(throws: JSONParseError.self) {
            try JSON(parsing: deep, options: .init(maximumDepth: 50))
        }
    }
}

// MARK: - Serializer

@Suite
struct JSONSerializerTests {

    @Test func roundTrip() throws {
        let json: JSON = [
            "null": nil,
            "bool": true,
            "int": -42,
            "double": 1.5,
            "string": "héllo \"quotes\" \\ \n 😀",
            "array": [1, [2], ["3": 4]],
            "object": ["nested": ["deep": true]]
        ]
        let string = json.toString()
        #expect(try JSON(parsing: string) == json)
        let pretty = json.toString(options: [.prettyPrint, .sortedKeys])
        #expect(try JSON(parsing: pretty) == json)
        let data = json.toData()
        #expect(try JSON(parsing: data) == json)
    }

    @Test func sortedKeys() {
        let json: JSON = ["b": 2, "a": 1, "c": 3]
        #expect(json.toString(options: [.sortedKeys]) == #"{"a":1,"b":2,"c":3}"#)
    }

    @Test func escaping() {
        let expected = "\"" + "\\\"" + "\\\\" + "\\b" + "\\f" + "\\n" + "\\r" + "\\t" + "\\u0001" + "\""
        #expect(JSON.string("\"\\\u{08}\u{0C}\n\r\t\u{01}").toString() == expected)
    }

    @Test func numbers() {
        #expect(JSON.integer(42).toString() == "42")
        #expect(JSON.integer(0).toString() == "0")
        #expect(JSON.integer(-7).toString() == "-7")
        #expect(JSON.integer(.max).toString() == "9223372036854775807")
        #expect(JSON.integer(.min).toString() == "-9223372036854775808")
        #expect(JSON.double(1.5).toString() == "1.5")
        #expect(JSON.double(2).toString() == "2")
        #expect(JSON.double(0).toString() == "0")
        #expect(JSON.double(.infinity).toString() == "null")
        #expect(JSON.double(.nan).toString() == "null")
    }

    @Test func strings() {
        #expect(JSON.string("").toString() == "\"\"")
        #expect(JSON.string("plain").toString() == "\"plain\"")
        #expect(JSON.string("a\"b\\c").toString() == #""a\"b\\c""#)
        #expect(JSON.string("é😀").toString() == "\"é😀\"")
    }

    @Test func literals() {
        #expect(JSON.null.toString() == "null")
        #expect(JSON.bool(true).toString() == "true")
        #expect(JSON.bool(false).toString() == "false")
    }

    @Test func prettyPrint() {
        let json: JSON = ["a": [1, 2]]
        let expected = """
        {
          "a": [
            1,
            2
          ]
        }
        """
        #expect(json.toString(options: [.prettyPrint, .sortedKeys]) == expected)
    }

    @Test func empty() {
        #expect(JSON.object([:]).toString(options: [.prettyPrint]) == "{}")
        #expect(JSON.array([]).toString(options: [.prettyPrint]) == "[]")
    }
}

// MARK: - Coding

struct Person: JSONEncodable, JSONDecodable, Equatable {

    let id: UUID

    var name: String

    var age: UInt8?

    var website: URL?

    var avatar: Data?

    var created: Date

    var role: Role

    enum Role: String, JSONEncodable, JSONDecodable {

        case admin
        case user
    }

    enum CodingKeys: String, CodingKey {

        case id
        case name
        case age
        case website
        case avatar
        case created
        case role
    }

    init(
        id: UUID,
        name: String,
        age: UInt8? = nil,
        website: URL? = nil,
        avatar: Data? = nil,
        created: Date,
        role: Role = .user
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.website = website
        self.avatar = avatar
        self.created = created
        self.role = role
    }

    init(from json: JSON) throws(JSONDecodeError) {
        self.id = try json.decode(UUID.self, forKey: CodingKeys.id)
        self.name = try json.decode(String.self, forKey: CodingKeys.name)
        self.age = try json.decodeIfPresent(UInt8.self, forKey: CodingKeys.age)
        self.website = try json.decodeIfPresent(URL.self, forKey: CodingKeys.website)
        self.avatar = try json.decodeIfPresent(Data.self, forKey: CodingKeys.avatar)
        self.created = try json.decode(Date.self, forKey: CodingKeys.created)
        self.role = try json.decode(Role.self, forKey: CodingKeys.role)
    }

    func encode() -> JSON {
        var json = JSON.object([:])
        json.encode(id, forKey: CodingKeys.id)
        json.encode(name, forKey: CodingKeys.name)
        json.encodeIfPresent(age, forKey: CodingKeys.age)
        json.encodeIfPresent(website, forKey: CodingKeys.website)
        json.encodeIfPresent(avatar, forKey: CodingKeys.avatar)
        json.encode(created, forKey: CodingKeys.created)
        json.encode(role, forKey: CodingKeys.role)
        return json
    }
}

@Suite
struct JSONCodingTests {

    @Test func roundTrip() throws {
        let person = Person(
            id: UUID(),
            name: "Alsey",
            age: 28,
            website: URL(string: "https://pureswift.github.io"),
            avatar: Data([0x00, 0x01, 0x02, 0xFF]),
            created: Date(timeIntervalSince1970: 1_000_000),
            role: .admin
        )
        let json = person.encode()
        let string = json.toString(options: [.sortedKeys])
        let parsed = try JSON(parsing: string)
        let decoded = try Person(from: parsed)
        #expect(decoded == person)
    }

    @Test func optionals() throws {
        let person = Person(
            id: UUID(),
            name: "Anonymous",
            created: Date(timeIntervalSince1970: 0)
        )
        let json = person.encode()
        // absent values are omitted, not encoded as null
        #expect(json["age"] == nil)
        #expect(json["website"] == nil)
        let decoded = try Person(from: json)
        #expect(decoded == person)
        #expect(decoded.age == nil)
        // explicit null also decodes as nil
        var withNull = json
        withNull.encode(Optional<UInt8>.none, forKey: Person.CodingKeys.age)
        #expect(withNull["age"] == .null)
        #expect(try Person(from: withNull).age == nil)
    }

    @Test func keyNotFound() {
        let json = JSON.object([:])
        #expect(throws: JSONDecodeError.keyNotFound("name")) {
            try json.decode(String.self, forKey: Person.CodingKeys.name)
        }
    }

    @Test func typeMismatch() {
        let json = JSON.object(["name": .integer(1)])
        #expect(throws: JSONDecodeError.typeMismatch("name", .integer(1))) {
            try json.decode(String.self, forKey: Person.CodingKeys.name)
        }
    }

    @Test func integerBounds() throws {
        let json = JSON.object(["age": .integer(300)])
        #expect(throws: JSONDecodeError.self) {
            try json.decode(UInt8.self, forKey: Person.CodingKeys.age)
        }
        #expect(try json.decode(UInt16.self, forKey: Person.CodingKeys.age) == 300)
    }

    @Test func collections() throws {
        let values = [1, 2, 3]
        let json = values.encode()
        #expect(json == .array([.integer(1), .integer(2), .integer(3)]))
        #expect(try [Int](from: json) == values)
        let dictionary = ["a": true, "b": false]
        let objectJSON = dictionary.encode()
        #expect(try [String: Bool](from: objectJSON) == dictionary)
    }
}

// MARK: - Base64

@Suite
struct Base64Tests {

    @Test func roundTrip() throws {
        // exercises the internal Base64 codec through the `Data` coding API
        let vectors: [(bytes: [UInt8], encoded: String)] = [
            ([], ""),
            (Array("f".utf8), "Zg=="),
            (Array("fo".utf8), "Zm8="),
            (Array("foo".utf8), "Zm9v"),
            (Array("foob".utf8), "Zm9vYg=="),
            (Array("fooba".utf8), "Zm9vYmE="),
            (Array("foobar".utf8), "Zm9vYmFy"),
            ([0x00, 0xFF, 0x7F], "AP9/"),
            ([0xFB, 0xEF, 0xBE], "++++")
        ]
        for vector in vectors {
            #expect(Data(vector.bytes).encode() == .string(vector.encoded))
            #expect(try Data(from: .string(vector.encoded)) == Data(vector.bytes))
        }
    }

    @Test func invalid() {
        #expect(throws: JSONDecodeError.self) {
            try Data(from: .string("Zg=!"))
        }
        #expect(throws: JSONDecodeError.self) {
            try Data(from: .string("Zg==Zg"))
        }
        #expect(throws: JSONDecodeError.self) {
            try Data(from: .string("😀"))
        }
        #expect(throws: JSONDecodeError.self) {
            try Data(from: .integer(1))
        }
        #expect(throws: JSONDecodeError.self) {
            try Data(from: .string("Zg===")) // excess padding
        }
    }
}

// MARK: - Conformances

@Suite
struct JSONEncodableConformanceTests {

    @Test func json() {
        #expect(JSON.string("a").encode() == .string("a"))
    }

    @Test func optionals() {
        #expect(Optional<Int>.none.encode() == .null)
        #expect(Optional<Int>.some(1).encode() == .integer(1))
    }

    @Test func integers() {
        #expect(Int(1).encode() == .integer(1))
        #expect(Int8(-2).encode() == .integer(-2))
        #expect(Int16(3).encode() == .integer(3))
        #expect(Int32(-4).encode() == .integer(-4))
        #expect(Int64(5).encode() == .integer(5))
        #expect(UInt(6).encode() == .integer(6))
        #expect(UInt8(7).encode() == .integer(7))
        #expect(UInt16(8).encode() == .integer(8))
        #expect(UInt32(9).encode() == .integer(9))
        #expect(UInt64(10).encode() == .integer(10))
        // values above Int64.max are clamped
        #expect(UInt64.max.encode() == .integer(.max))
    }

    @Test func floatingPoint() {
        #expect(Float(1.5).encode() == .double(1.5))
        #expect(Double(2.5).encode() == .double(2.5))
    }

    @Test func other() {
        #expect(true.encode() == .bool(true))
        #expect("a".encode() == .string("a"))
        #expect(Person.Role.admin.encode() == .string("admin"))
        #expect([1, 2].encode() == .array([.integer(1), .integer(2)]))
        #expect(["a": true].encode() == .object(["a": .bool(true)]))
    }

    @Test func keyedEncoding() {
        // encoding into a non-object receiver replaces it with an object
        var json = JSON.null
        json.encode(1, forKey: Person.CodingKeys.age)
        #expect(json == .object(["age": .integer(1)]))
    }
}

@Suite
struct JSONDecodableConformanceTests {

    @Test func json() throws {
        #expect(JSON(from: .string("a")) == .string("a"))
    }

    @Test func optionals() throws {
        #expect(try Optional<Int>(from: .null) == Optional<Int>.none)
        #expect(try Optional<Int>(from: .integer(1)) == 1)
        #expect(throws: JSONDecodeError.self) {
            try Optional<Int>(from: .string("a"))
        }
    }

    @Test func rawRepresentable() throws {
        #expect(try Person.Role(from: .string("admin")) == .admin)
        // invalid raw value
        #expect(throws: JSONDecodeError.self) {
            try Person.Role(from: .string("superadmin"))
        }
        // invalid value type
        #expect(throws: JSONDecodeError.self) {
            try Person.Role(from: .integer(1))
        }
    }

    @Test func integers() throws {
        #expect(try Int(from: .integer(1)) == 1)
        #expect(try Int8(from: .integer(-2)) == -2)
        #expect(try Int16(from: .integer(3)) == 3)
        #expect(try Int32(from: .integer(-4)) == -4)
        #expect(try Int64(from: .integer(5)) == 5)
        #expect(try UInt(from: .integer(6)) == 6)
        #expect(try UInt8(from: .integer(7)) == 7)
        #expect(try UInt16(from: .integer(8)) == 8)
        #expect(try UInt32(from: .integer(9)) == 9)
        #expect(try UInt64(from: .integer(10)) == 10)
        // out of range
        #expect(throws: JSONDecodeError.self) {
            try Int8(from: .integer(300))
        }
        #expect(throws: JSONDecodeError.self) {
            try UInt8(from: .integer(-1))
        }
        // invalid value type
        #expect(throws: JSONDecodeError.self) {
            try Int(from: .string("1"))
        }
    }

    @Test func floatingPoint() throws {
        #expect(try Float(from: .double(1.5)) == 1.5)
        #expect(try Double(from: .double(2.5)) == 2.5)
        #expect(try Double(from: .integer(2)) == 2.0)
        #expect(throws: JSONDecodeError.self) {
            try Float(from: .string("a"))
        }
        #expect(throws: JSONDecodeError.self) {
            try Double(from: .string("a"))
        }
    }

    @Test func other() throws {
        #expect(try Bool(from: .bool(true)) == true)
        #expect(try String(from: .string("a")) == "a")
        #expect(throws: JSONDecodeError.self) {
            try Bool(from: .integer(1))
        }
        #expect(throws: JSONDecodeError.self) {
            try String(from: .integer(1))
        }
    }

    @Test func arrays() throws {
        #expect(try [Int](from: .array([.integer(1), .integer(2)])) == [1, 2])
        // not an array
        #expect(throws: JSONDecodeError.self) {
            try [Int](from: .string("a"))
        }
        // invalid element
        #expect(throws: JSONDecodeError.self) {
            try [Int](from: .array([.integer(1), .string("a")]))
        }
    }

    @Test func dictionaries() throws {
        #expect(try [String: Int](from: .object(["a": .integer(1)])) == ["a": 1])
        // not an object
        #expect(throws: JSONDecodeError.self) {
            try [String: Int](from: .array([]))
        }
        // invalid value
        #expect(throws: JSONDecodeError.self) {
            try [String: Int](from: .object(["a": .string("b")]))
        }
    }

    @Test func decodeIfPresentMismatch() {
        let json = JSON.object(["age": .string("old")])
        #expect(throws: JSONDecodeError.typeMismatch("age", .string("old"))) {
            try json.decodeIfPresent(UInt8.self, forKey: Person.CodingKeys.age)
        }
    }

    @Test func decodeOnNonObject() throws {
        #expect(throws: JSONDecodeError.keyNotFound("age")) {
            try JSON.string("a").decode(UInt8.self, forKey: Person.CodingKeys.age)
        }
        #expect(try JSON.string("a").decodeIfPresent(UInt8.self, forKey: Person.CodingKeys.age) == nil)
    }
}

// MARK: - Foundation Types

@Suite
struct JSONFoundationCodingTests {

    @Test func uuid() throws {
        let uuid = UUID()
        #expect(uuid.encode() == .string(uuid.uuidString))
        #expect(try UUID(from: .string(uuid.uuidString)) == uuid)
        #expect(throws: JSONDecodeError.self) {
            try UUID(from: .string("not a uuid"))
        }
        #expect(throws: JSONDecodeError.self) {
            try UUID(from: .integer(1))
        }
    }

    @Test func url() throws {
        let url = URL(string: "https://pureswift.github.io")!
        #expect(url.encode() == .string("https://pureswift.github.io"))
        #expect(try URL(from: .string("https://pureswift.github.io")) == url)
        #expect(throws: JSONDecodeError.self) {
            try URL(from: .string(""))
        }
        #expect(throws: JSONDecodeError.self) {
            try URL(from: .integer(1))
        }
    }

    @Test func date() throws {
        let date = Date(timeIntervalSince1970: 1_000_000)
        #expect(date.encode() == .double(1_000_000))
        #expect(try Date(from: .double(1_000_000)) == date)
        #expect(try Date(from: .integer(1_000_000)) == date)
        #expect(throws: JSONDecodeError.self) {
            try Date(from: .string("a"))
        }
    }

    @Test func data() throws {
        let data = Data([0x00, 0x01, 0xFF])
        #expect(data.encode() == .string("AAH/"))
        #expect(try Data(from: .string("AAH/")) == data)
        #expect(throws: JSONDecodeError.self) {
            try Data(from: .integer(1))
        }
    }

    @Test func decimal() throws {
        let decimal = Decimal(string: "1.25")!
        #expect(decimal.encode() == .string("1.25"))
        #expect(try Decimal(from: .string("1.25")) == decimal)
        #expect(throws: JSONDecodeError.self) {
            try Decimal(from: .string("not a number"))
        }
        #expect(throws: JSONDecodeError.self) {
            try Decimal(from: .integer(1))
        }
    }
}
