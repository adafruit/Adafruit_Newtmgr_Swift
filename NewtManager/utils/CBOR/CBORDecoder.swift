import Foundation


open class CBORDecoder {

	fileprivate var data : Data

	public init(data: Data) {
		self.data = data
	}
    
    fileprivate func readUInt<T: UnsignedInteger>(_ n: Int) throws -> T {
        guard data.count >= n else {
            throw CBORError.unfinishedSequence
        }
        
        let result: T = data.scanValue(start: 0, length: n)
        data.removeFirst(n)

        return result
    }
    
    fileprivate func readBytes(_ n: Int) throws -> ArraySlice<UInt8> {
        guard data.count >= n else {
            throw CBORError.unfinishedSequence
        }
        
        let result = data.prefix(n)
        data.removeFirst(n)
        return ArraySlice(result)
    }
    
    fileprivate func readN(_ n: Int) throws -> [CBOR] {
        return try (0..<n).map { _ in guard let r = try decodeItem() else { throw CBORError.unfinishedSequence }; return r }
	}

	fileprivate func readUntilBreak() throws -> [CBOR] {
		var result : [CBOR] = []
		var cur = try decodeItem()
		while (cur != CBOR.break) {
			guard let curr = cur else { throw CBORError.unfinishedSequence }
			result.append(curr)
			cur = try decodeItem()
		}
		return result
	}

	fileprivate func readNPairs(_ n: Int) throws -> [CBOR : CBOR] {
		var result : [CBOR : CBOR] = [:]
		for _ in (0..<n) {
			guard let key  = try decodeItem() else { throw CBORError.unfinishedSequence }
			guard let val  = try decodeItem() else { throw CBORError.unfinishedSequence }
			result[key] = val
		}
		return result
	}

	fileprivate func readPairsUntilBreak() throws -> [CBOR : CBOR] {
		var result : [CBOR : CBOR] = [:]
		var key = try decodeItem()
		var val = try decodeItem()
		while (key != CBOR.break) {
			guard let okey = key else { throw CBORError.unfinishedSequence }
			guard let oval = val else { throw CBORError.unfinishedSequence }
			result[okey] = oval
			do { key = try decodeItem() } catch CBORError.unfinishedSequence { key = nil }
			guard (key != CBOR.break) else { break } // don't eat the val after the break!
			do { val = try decodeItem() } catch CBORError.unfinishedSequence { val = nil }
		}
		return result
	}

	open func decodeItem() throws -> CBOR? {
    
		switch try readUInt(1) as UInt8 {
		case let b where b <= 0x17: return CBOR.unsignedInt(UInt(b))
		case 0x18: return CBOR.unsignedInt(UInt(try readUInt(1) as UInt8))
		case 0x19: return CBOR.unsignedInt(UInt(try readUInt(2) as UInt16))
		case 0x1a: return CBOR.unsignedInt(UInt(try readUInt(4) as UInt32))
		case 0x1b: return CBOR.unsignedInt(UInt(try readUInt(8) as UInt64))

		case let b where 0x20 <= b && b <= 0x37: return CBOR.negativeInt(UInt(b - 0x20))
		case 0x38: return CBOR.negativeInt(UInt(try readUInt(1) as UInt8))
		case 0x39: return CBOR.negativeInt(UInt(try readUInt(2) as UInt16))
		case 0x3a: return CBOR.negativeInt(UInt(try readUInt(4) as UInt32))
		case 0x3b: return CBOR.negativeInt(UInt(try readUInt(8) as UInt64))

		case let b where 0x40 <= b && b <= 0x57: return CBOR.byteString(Array(try readBytes(Int(b - 0x40))))
		case 0x58: return CBOR.byteString(Array(try readBytes(Int(try readUInt(1) as UInt8))))
		case 0x59: return CBOR.byteString(Array(try readBytes(Int(try readUInt(2) as UInt16))))
		case 0x5a: return CBOR.byteString(Array(try readBytes(Int(try readUInt(4) as UInt32))))
		case 0x5b: return CBOR.byteString(Array(try readBytes(Int(try readUInt(8) as UInt64))))
		case 0x5f: return CBOR.byteString(try readUntilBreak().flatMap { x -> [UInt8] in guard case .byteString(let r) = x else { throw CBORError.wrongTypeInsideSequence }; return r })

		case let b where 0x60 <= b && b <= 0x77: return CBOR.utf8String(try Util.decodeUtf8(try readBytes(Int(b - 0x60))))
		case 0x78: return CBOR.utf8String(try Util.decodeUtf8(try readBytes(Int(try readUInt(1) as UInt8))))
		case 0x79: return CBOR.utf8String(try Util.decodeUtf8(try readBytes(Int(try readUInt(2) as UInt16))))
		case 0x7a: return CBOR.utf8String(try Util.decodeUtf8(try readBytes(Int(try readUInt(4) as UInt32))))
		case 0x7b: return CBOR.utf8String(try Util.decodeUtf8(try readBytes(Int(try readUInt(8) as UInt64))))
		case 0x7f: return CBOR.utf8String(try readUntilBreak().map { x -> String in guard case .utf8String(let r) = x else { throw CBORError.wrongTypeInsideSequence }; return r }.joined(separator: ""))

		case let b where 0x80 <= b && b <= 0x97: return CBOR.array(try readN(Int(b - 0x80)))
		case 0x98: return CBOR.array(try readN(Int(try readUInt(1) as UInt8)))
		case 0x99: return CBOR.array(try readN(Int(try readUInt(2) as UInt16)))
		case 0x9a: return CBOR.array(try readN(Int(try readUInt(4) as UInt32)))
		case 0x9b: return CBOR.array(try readN(Int(try readUInt(8) as UInt64)))
		case 0x9f: return CBOR.array(try readUntilBreak())

		case let b where 0xa0 <= b && b <= 0xb7: return CBOR.map(try readNPairs(Int(b - 0xa0)))
		case 0xb8: return CBOR.map(try readNPairs(Int(try readUInt(1) as UInt8)))
		case 0xb9: return CBOR.map(try readNPairs(Int(try readUInt(2) as UInt16)))
		case 0xba: return CBOR.map(try readNPairs(Int(try readUInt(4) as UInt32)))
		case 0xbb: return CBOR.map(try readNPairs(Int(try readUInt(8) as UInt64)))
		case 0xbf: return CBOR.map(try readPairsUntilBreak())

		case let b where 0xc0 <= b && b <= 0xd7:
			guard let item = try decodeItem() else { throw CBORError.unfinishedSequence }
			return CBOR.tagged(UInt(b - 0xc0), item)
		case 0xd8:
			let tag = UInt(try readUInt(1) as UInt8)
			guard let item = try decodeItem() else { throw CBORError.unfinishedSequence }
			return CBOR.tagged(tag, item)
		case 0xd9:
			let tag = UInt(try readUInt(2) as UInt16)
			guard let item = try decodeItem() else { throw CBORError.unfinishedSequence }
			return CBOR.tagged(tag, item)
		case 0xda:
			let tag = UInt(try readUInt(4) as UInt32)
			guard let item = try decodeItem() else { throw CBORError.unfinishedSequence }
			return CBOR.tagged(tag, item)
		case 0xdb:
			let tag = UInt(try readUInt(8) as UInt64)
			guard let item = try decodeItem() else { throw CBORError.unfinishedSequence }
			return CBOR.tagged(tag, item)

		case let b where 0xe0 <= b && b <= 0xf3: return CBOR.simple(b - 0xe0)
		case 0xf4: return CBOR.boolean(false)
		case 0xf5: return CBOR.boolean(true)
		case 0xf6: return CBOR.null
		case 0xf7: return CBOR.undefined
		case 0xf8: return CBOR.simple(try readUInt(1) as UInt8)
        
        case 0xf9:
            var uInt16: UInt16 = try readUInt(2)
            return CBOR.half(loadFromF16(&uInt16))

        case 0xfa:
            let bytes = Array(Array(try readBytes(4)).reversed())
            let float32 = UnsafePointer(bytes).withMemoryRebound(to: Float32.self, capacity: 1) {
                $0.pointee
            }
            return CBOR.float(float32)

        case 0xfb:
            let bytes = Array(Array(try readBytes(8)).reversed())
            let float64 = UnsafePointer(bytes).withMemoryRebound(to: Float64.self, capacity: 1) {
                $0.pointee
            }
            return CBOR.double(float64)

            
		case 0xff: return CBOR.break
		default: return nil
		}
	}

}
