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
@testable import JSON

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
        #expect(JSON.double(1.5).toString() == "1.5")
        #expect(JSON.double(2).toString() == "2")
        #expect(JSON.double(.infinity).toString() == "null")
        #expect(JSON.double(.nan).toString() == "null")
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

    @Test func roundTrip() {
        let vectors: [(bytes: [UInt8], encoded: String)] = [
            ([], ""),
            (Array("f".utf8), "Zg=="),
            (Array("fo".utf8), "Zm8="),
            (Array("foo".utf8), "Zm9v"),
            (Array("foob".utf8), "Zm9vYg=="),
            (Array("fooba".utf8), "Zm9vYmE="),
            (Array("foobar".utf8), "Zm9vYmFy"),
            ([0x00, 0xFF, 0x7F], "AP9/")
        ]
        for vector in vectors {
            #expect(Base64.encode(vector.bytes) == vector.encoded)
            #expect(Base64.decode(vector.encoded) == vector.bytes)
        }
    }

    @Test func invalid() {
        #expect(Base64.decode("Zg=!") == nil)
        #expect(Base64.decode("Zg==Zg") == nil)
        #expect(Base64.decode("😀") == nil)
    }
}
