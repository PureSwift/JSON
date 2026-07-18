//
//  Base64.swift
//  JSON
//
//  Minimal Base64 codec, used for `Data` coding so behavior is identical
//  across Foundation, FoundationEssentials and FoundationEmbedded.
//
//  Created by Alsey Coleman Miller on 7/18/26.
//

internal enum Base64 {

    private static let alphabet: [UInt8] = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8
    )

    /// Encodes bytes as a Base64 string.
    static func encode<C: Collection>(_ bytes: C) -> String where C.Element == UInt8 {
        var output = [UInt8]()
        output.reserveCapacity(((bytes.count + 2) / 3) * 4)
        var iterator = bytes.makeIterator()
        while let byte0 = iterator.next() {
            let byte1 = iterator.next()
            let byte2 = iterator.next()
            output.append(alphabet[Int(byte0 >> 2)])
            output.append(alphabet[Int((byte0 & 0b11) << 4 | (byte1 ?? 0) >> 4)])
            if let byte1 {
                output.append(alphabet[Int((byte1 & 0b1111) << 2 | (byte2 ?? 0) >> 6)])
            } else {
                output.append(UInt8(ascii: "="))
            }
            if let byte2 {
                output.append(alphabet[Int(byte2 & 0b111111)])
            } else {
                output.append(UInt8(ascii: "="))
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// Decodes a Base64 string into bytes.
    static func decode(_ string: String) -> [UInt8]? {
        var buffer: UInt32 = 0
        var bitCount = 0
        var output = [UInt8]()
        output.reserveCapacity((string.utf8.count / 4) * 3)
        var padding = 0
        for character in string.utf8 {
            let value: UInt32
            switch character {
            case UInt8(ascii: "A") ... UInt8(ascii: "Z"):
                value = UInt32(character - UInt8(ascii: "A"))
            case UInt8(ascii: "a") ... UInt8(ascii: "z"):
                value = UInt32(character - UInt8(ascii: "a")) + 26
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                value = UInt32(character - UInt8(ascii: "0")) + 52
            case UInt8(ascii: "+"):
                value = 62
            case UInt8(ascii: "/"):
                value = 63
            case UInt8(ascii: "="):
                padding += 1
                continue
            default:
                return nil
            }
            // no characters allowed after padding
            guard padding == 0 else { return nil }
            buffer = (buffer << 6) | value
            bitCount += 6
            if bitCount >= 8 {
                bitCount -= 8
                output.append(UInt8(truncatingIfNeeded: buffer >> UInt32(bitCount)))
            }
        }
        guard padding <= 2 else { return nil }
        return output
    }
}
