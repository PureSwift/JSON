//
//  CodableComparisonTests.swift
//  JSON
//
//  Cross-implementation comparison against Foundation's `Codable` machinery
//  (`JSONEncoder` / `JSONDecoder` from FoundationEssentials or Foundation):
//  interop correctness in both directions, plus an informational performance
//  comparison printed to the test log.
//
//  Created by Alsey Coleman Miller on 7/19/26.
//

#if canImport(FoundationEssentials) || canImport(Foundation)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Testing
import JSON

/// Fixture conforming to both Foundation `Codable` and this library's
/// hand-written `JSONEncodable` / `JSONDecodable`.
struct ComparisonItem: Codable, Equatable, JSONEncodable, JSONDecodable {

    let id: Int

    var name: String

    var active: Bool

    var score: Double

    var tags: [String]

    var note: String?

    enum CodingKeys: String, CodingKey {

        case id
        case name
        case active
        case score
        case tags
        case note
    }

    init(id: Int, name: String, active: Bool, score: Double, tags: [String], note: String? = nil) {
        self.id = id
        self.name = name
        self.active = active
        self.score = score
        self.tags = tags
        self.note = note
    }

    init(from json: JSON) throws(JSONDecodeError) {
        self.id = try json.decode(Int.self, forKey: CodingKeys.id)
        self.name = try json.decode(String.self, forKey: CodingKeys.name)
        self.active = try json.decode(Bool.self, forKey: CodingKeys.active)
        self.score = try json.decode(Double.self, forKey: CodingKeys.score)
        self.tags = try json.decode([String].self, forKey: CodingKeys.tags)
        self.note = try json.decodeIfPresent(String.self, forKey: CodingKeys.note)
    }

    func encode() -> JSON {
        var json = JSON.object([:])
        json.encode(id, forKey: CodingKeys.id)
        json.encode(name, forKey: CodingKeys.name)
        json.encode(active, forKey: CodingKeys.active)
        json.encode(score, forKey: CodingKeys.score)
        json.encode(tags, forKey: CodingKeys.tags)
        json.encodeIfPresent(note, forKey: CodingKeys.note)
        return json
    }

    static func fixtures(count: Int) -> [ComparisonItem] {
        var items = [ComparisonItem]()
        items.reserveCapacity(count)
        for i in 0 ..< count {
            items.append(
                ComparisonItem(
                    id: i,
                    name: "item number \(i)",
                    active: i % 2 == 0,
                    score: Double(i) * 1.5,
                    tags: ["alpha", "beta", "gamma"],
                    note: i % 3 == 0 ? "an \"escaped\" note with é" : nil
                )
            )
        }
        return items
    }
}

@Suite
struct CodableComparisonTests {

    /// JSON produced by Foundation's `JSONEncoder` decodes identically
    /// through this library.
    @Test func decodeFoundationOutput() throws {
        let items = ComparisonItem.fixtures(count: 100)
        let foundationData = try JSONEncoder().encode(items)
        let json = try JSON(parsing: foundationData)
        let decoded = try [ComparisonItem](from: json)
        #expect(decoded == items)
    }

    /// JSON produced by this library decodes identically through
    /// Foundation's `JSONDecoder`.
    @Test func foundationDecodesOurOutput() throws {
        let items = ComparisonItem.fixtures(count: 100)
        let data = items.encode().toData()
        let decoded = try JSONDecoder().decode([ComparisonItem].self, from: data)
        #expect(decoded == items)
    }

    /// Both implementations agree on a full round trip in either direction.
    @Test func crossRoundTrip() throws {
        let items = ComparisonItem.fixtures(count: 50)
        // ours → Foundation → ours
        let a = try [ComparisonItem](from: try JSON(parsing: try JSONEncoder().encode(
            try JSONDecoder().decode([ComparisonItem].self, from: items.encode().toData())
        )))
        #expect(a == items)
    }

    #if !DEBUG
    /// Informational performance comparison — decode and encode throughput
    /// vs. Foundation `Codable`. Prints results; no timing assertion, since
    /// CI hosts (emulators in particular) have unstable clocks.
    ///
    /// - Note: Compiled only in release configuration (`swift test -c release`).
    ///   Debug timings are meaningless for comparison: the generic keyed
    ///   coding helpers are not specialized without optimization.
    @Test func performance() throws {
        let items = ComparisonItem.fixtures(count: 2_000)
        let data = try JSONEncoder().encode(items)
        let megabytes = Double(data.count) / 1_048_576
        let iterations = 5
        let clock = ContinuousClock()

        func measure(_ body: () throws -> Void) rethrows -> Double {
            try body() // warmup
            var best = Double.greatestFiniteMagnitude
            for _ in 0 ..< iterations {
                let start = clock.now
                try body()
                let elapsed = clock.now - start
                let seconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18
                best = min(best, seconds)
            }
            return best
        }

        let oursDecode = try measure {
            _ = try [ComparisonItem](from: try JSON(parsing: data))
        }
        let foundationDecode = try measure {
            _ = try JSONDecoder().decode([ComparisonItem].self, from: data)
        }
        let oursEncode = measure {
            _ = items.encode().toData()
        }
        let foundationEncode = try measure {
            _ = try JSONEncoder().encode(items)
        }

        // Rounds to `places` decimals for display. `String(format:)` is avoided
        // because it lives in full Foundation, not FoundationEssentials, so it
        // is unavailable on platforms (Android, Windows) that import the latter.
        func rounded(_ value: Double, _ places: Int) -> Double {
            var factor = 1.0
            for _ in 0 ..< places { factor *= 10 }
            return (value * factor).rounded() / factor
        }
        func report(_ name: String, _ seconds: Double) {
            let ms = rounded(seconds * 1000, 3)
            let throughput = rounded(megabytes / seconds, 1)
            print("\(name): \(ms) ms (\(throughput) MB/s)")
        }
        print("Codable comparison — \(data.count) bytes, \(items.count) items")
        report("decode  JSON library    ", oursDecode)
        report("decode  Foundation      ", foundationDecode)
        report("encode  JSON library    ", oursEncode)
        report("encode  Foundation      ", foundationEncode)
        print("decode ratio (ours/Foundation): \(rounded(oursDecode / foundationDecode, 2))×")
        print("encode ratio (ours/Foundation): \(rounded(oursEncode / foundationEncode, 2))×")
    }
    #endif
}

#endif
