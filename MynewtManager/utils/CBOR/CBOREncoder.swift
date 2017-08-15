//
//  CBOREncoder.swift
//  MynewtManager
//
//  Created by Antonio García on 01/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class CBOREncoder {
    enum MajorType: UInt8 {
        case unsignedInt = 0
        case negativeInt = 1
        case byteString = 2
        case textString = 3
        case array = 4
        case map = 5
        case tag = 6
        case simple = 7
    }
    
    private static let kOneByte: UInt8 = 0x18
    private static let kTwoBytes: UInt8 = 0x19
    private static let kFourBytes: UInt8 = 0x1a
    private static let kEightBytes: UInt8 = 0x1b
    
    private static let kFalse: UInt8 = 0x14
    private static let kTrue: UInt8 = 0x15
    private static let kNull: UInt8 = 0x16
    private static let kUndefined: UInt8 = 0x17

    private static let kHalfPrecisionFloat: UInt8 = 0x19
    private static let kSinglePrecisionFloat: UInt8 = 0x1a
    private static let kDoublePrecisionFloat: UInt8 = 0x1b
    private static let kBreak: UInt8 = 0x1f
    
    private static let kNegativeIntMask = MajorType.negativeInt.rawValue << 5
    
    func encodeItemAsData(cbor: CBOR) throws -> Data {
        let bytes = try encodeItemAsBytes(cbor: cbor)
        return Data(bytes: bytes)
    }
    
    func encodeItemAsBytes(cbor: CBOR) throws -> [UInt8] {
        switch cbor {
        case let .unsignedInt(value):
            return encode(int: Int(value), majorType: .unsignedInt)
        case let .negativeInt(value):
            return encode(int: -Int(value)-1, majorType: .negativeInt)
        case let .byteString(bytes):
            return encode(bytes: bytes)
        case let .utf8String(text):
            return encode(text: text)
        case let .array(array):
            return try encode(array: array)
        case let .map(dictionary):
            return try encode(dicionary: dictionary)
        case .tagged: // (tag, value):
            // TODO: implement me
            DLog("Error: CBOR tag encoding not implemented")
        case .simple: // (value):
            // TODO: implement me
            DLog("Error: CBOR simple encoding not implemented")
        case let .boolean(value):
            return encode(simple: value ? CBOREncoder.kTrue : CBOREncoder.kFalse)
        case .null:
            return encode(simple: CBOREncoder.kNull)
        case .undefined:
            return encode(simple: CBOREncoder.kUndefined)
        case .half: //(value):
            // TODO: implement me
            DLog("Error: CBOR half encoding not implemented")
        case .float: //(value):
            // TODO: implement me
            DLog("Error: CBOR half encoding not implemented")
        case .double: //(value):
            // TODO: implement me
            DLog("Error: CBOR half encoding not implemented")
        case .break:
            return encode(simple: CBOREncoder.kBreak)
            
        case .error:
            throw CBORError.invalidCBOR
        }
        
        return []
    }

    /*
    private func encode(tag: UInt, value: CBOR) -> [UInt8] {
        // TODO: implement me
        DLog("Error: Tag encoding not implemented")
    }*/
    
    private func encode(simple value: UInt8) -> [UInt8] {
        let majorTypeMask = MajorType.simple.rawValue << 5
        return [majorTypeMask | UInt8(value & 0x1f)]
    }
    
    private func encode(dicionary: [CBOR:CBOR]) throws -> [UInt8] {
        var result = encode(int: dicionary.count, majorType: .map)
        for (key, value) in dicionary {
            let encodedKey = try encodeItemAsBytes(cbor: key)
            let encodedValue = try encodeItemAsBytes(cbor: value)
            result.append(contentsOf: encodedKey)
            result.append(contentsOf: encodedValue)
        }
        
        return result
    }

    private func encode(array: [CBOR]) throws -> [UInt8] {
        var result = encode(int: array.count, majorType: .array)
        for element in array {
            let encodedElement = try encodeItemAsBytes(cbor: element)
            result.append(contentsOf: encodedElement)
        }
        
        return result
    }

    private func encode(text: String) -> [UInt8] {
        let length = text.lengthOfBytes(using: .utf8)
        var result = encode(int: length, majorType: .textString)
        let bytes = [UInt8](text.utf8)
        result.append(contentsOf: bytes)
        return result
    }
    
    private func encode(bytes: [UInt8]) -> [UInt8] {
        let length = bytes.count
        var header = encode(int: length, majorType: .byteString)
        header.append(contentsOf: bytes)
        return header
    }

    private func encode(int value: Int, majorType: MajorType) -> [UInt8] {
        // FIX: it may fail to encode 64 bit values on 32bit platforms (iphone5s)
        
        let majorTypeMask = majorType.rawValue << 5
        
        if value <= 0x17 {
            return [majorTypeMask | toUInt8(value)]
        }
        else if value < 0x100 {
            return [majorTypeMask | CBOREncoder.kOneByte, toUInt8(value)]
        }
        else if value < 0x10000 {
            return [majorTypeMask | CBOREncoder.kTwoBytes, toUInt8(value >> 8), toUInt8(value)]
        }
        else if Int64(value) < 0x100000000 {
            return [majorTypeMask | CBOREncoder.kFourBytes, toUInt8(value >> 24), toUInt8(value >> 16), toUInt8(value >> 8), toUInt8(value)]
        }
        else {
            return [majorTypeMask | CBOREncoder.kEightBytes, toUInt8(value >> 56), toUInt8(value >> 48), toUInt8(value >> 40), toUInt8(value >> 32), toUInt8(value >> 24), toUInt8(value >> 16), toUInt8(value >> 8), toUInt8(value)]
        }
    }
    
    private func toUInt8(_ value: Int) -> UInt8 {
        return UInt8(value & 0xff)
    }
}
