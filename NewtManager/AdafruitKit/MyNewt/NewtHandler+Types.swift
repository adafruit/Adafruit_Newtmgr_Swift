//
//  Newt+Image.swift
//  NewtManager
//
//  Created by Antonio García on 03/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation



extension NewtHandler {
    // Alias
    typealias RequestCompletionHandler = ((_ data: Any?, _ error: Error?) -> Void)
    typealias RequestProgressHandler = ((_ progress: Float) -> Bool)    // Return value indicates if the operation should be cancelled
    
    // MARK: - Command
    enum Command {
        case imageList
        case imageTest(hash: Data)
        case imageConfirm(hash: Data?)
        case upload(imageData: Data)
        case taskStats
        case reset
        case echo(message: String)
        case stats
        case stat(statId: String)
    }
    
    // MARK: - TaskStats
    struct TaskStats {
        var taskId: UInt
        var name: String
        var priority: UInt
        var state: UInt
        var runTime: UInt
        var contextSwichCount: UInt
        var stackSize: UInt
        var stackUsed: UInt
        var lastSanityCheckin: UInt
        var nextSanityCheckin: UInt
    }
    
    // MARK: - StatDetails
    struct StatDetails {
        var name: String
        var value: UInt
    }
    
    // MARK: - NewtError
    enum NewtError: Error {
        case receivedResponseIsNotAPacket
        case receivedResponseIsNotACbor(Error?)
        case receivedResponseMissingFields
        case receviedResponseInvalidValues
        case receivedResultNotOk(String)
        case internalError
        case updateImageInvalid
        case imageInvalid
        case userCancelled
        case waitingForReponse
        
        var description: String {
            switch self {
            case .receivedResponseIsNotAPacket: return "Received response is not a packet"
            case .receivedResponseIsNotACbor(let error): return "Received invalid response: \(error?.localizedDescription ?? "")"
            case .receivedResponseMissingFields: return "Received response with missing fields"
            case .receviedResponseInvalidValues: return "Received response with invalid values"
            case .receivedResultNotOk(let message): return "Received incorrect result: \(message)"
            case .internalError: return "Internal error"
            case .updateImageInvalid: return "Upload image is invalid"
            case .imageInvalid: return "Image invalid"
            case .userCancelled: return "Cancelled"
            case .waitingForReponse: return "Waiting for previous command"
            }
        }
    }
    
    // MARK: - Image
    struct Image {
        var slot: Int
        var version: String
        var isConfirmed: Bool
        var isPending: Bool
        var isActive: Bool
        var isBootable: Bool
        var hash: Data
        
        private struct NewtImageHeader {
            static let kHeaderSize: UInt16    = 32
            static let kMagic: UInt32         = 0x96f3b83c
            static let kMagicNone: UInt32     = 0xffffffff
            static let kHashSize: UInt32      = 32
            static let kTlvSize: UInt32       = 4
        }
        
        private enum imgFlags: UInt32 {
            case SHA256                 = 0x00000002    // Image contains hash TLV
            case PKCS15_RSA2048_SHA256  = 0x00000004    // PKCS15 w/RSA and SHA
            case ECDSA224_SHA256        = 0x00000008    // ECDSA256 over SHA256
            
            var code: UInt32 {
                return rawValue
            }
        }
        
        // Image trailer TLV types.
        private enum imgTlvType : UInt8 {
            case SHA256   = 1 // SHA256 of image hdr and body
            case RSA2048  = 2 // RSA2048 of hash output
            case ECDSA224 = 3 // ECDSA of hash output
            
            var code: UInt8 {
                return rawValue
            }
        }
        
        struct imgVersion {
            var major: UInt8
            var minor: UInt8
            var revision: UInt16
            var buildNum: UInt32
            
            init() {
                self.major      = 0
                self.minor      = 0
                self.revision   = 0
                self.buildNum   = 0
            }
            
            var description: String {
                return String.init(format: "%d.%d.%d", major, minor, revision)
            }
        }
        
        // Image header.  All fields are in little endian byte order.
        private struct imgHeader {
            var magic: UInt32
            var tlvSize: UInt16  // Trailing TLVs
            var keyId: UInt8
            //uint8_t  _pad1;
            var hdrSize: UInt16
            //uint16_t _pad2;
            var imgSize: UInt32  // Does not include header.
            var flags :UInt32
            var ver: imgVersion
            //uint32_t _pad3;
            
            init?(magic: UInt32, tlvSize: UInt16, keyId: UInt8, hdrSize: UInt16, imgSize: UInt32, flags: UInt32, ver: imgVersion) {
                self.magic    = magic
                self.tlvSize  = tlvSize // Trailing TLVs
                self.keyId    = keyId
                //uint8_t  _pad1;
                self.hdrSize  = hdrSize
                //uint16_t _pad2;
                self.imgSize  = imgSize // Does not include header.
                self.flags     = flags
                self.ver = ver
            }
            
            init(imdata: Data) {
                magic = imdata.scanValue(start: 0, length: 4)
                tlvSize = imdata.scanValue(start: 4, length: 2)
                keyId = imdata.scanValue(start: 6, length: 1)
                //uint8_t  _pad1
                hdrSize = imdata.scanValue(start: 8, length: 2)
                //uint16_t _pad2;
                imgSize = imdata.scanValue(start: 12, length: 4)
                flags = imdata.scanValue(start: 16, length: 4)
                ver = imgVersion()
                ver.major = imdata.scanValue(start: 21, length: 1)
                ver.minor = imdata.scanValue(start: 22, length: 1)
                ver.revision = imdata.scanValue(start: 23, length: 2)
                ver.buildNum = imdata.scanValue(start: 25, length: 4)
            }
        }
        
        // Image trailer TLV format. All fields in little endian.
        private struct imgTlv {
            var type: UInt8
            //uint8_t  _pad;
            var len: UInt16
            
            init?(type: UInt8, len: UInt16) {
                self.type = type
                self.len  = len
            }
            
            init(imdata: Data) {
                type = imdata.scanValue(start: 0, length: 1)
                len = imdata.scanValue(start: 2, length: 2)
            }
        }
        
        static func readInfo(imageData data: Data) -> (version: imgVersion, hash: Data) {
            var hdr: imgHeader
            var tlv: imgTlv
            var ver = imgVersion()
            var hash = Data()
            var error: Error?
            
            hdr = imgHeader(imdata: data)
            
            if hdr.magic == NewtImageHeader.kMagic {
                ver = hdr.ver
            }
            else if (hdr.magic == 0xffffffff) {
                error = NewtError.imageInvalid
            }
            else {
                error = NewtError.imageInvalid
            }
            
            if error == nil {
                // Build ID is in a TLV after the image.
                var dataOff = UInt32(hdr.hdrSize) + UInt32(hdr.imgSize)
                let dataEnd = dataOff + UInt32(hdr.tlvSize)
                
                while (dataOff + NewtImageHeader.kTlvSize  <= dataEnd) {
                    let imdata = data.subdata(in: Int(dataOff)..<Int(dataOff)+Int(NewtImageHeader.kTlvSize))
                    tlv = imgTlv(imdata: imdata)
                    if (tlv.type == 0xff && tlv.len == 0xffff) {
                        break;
                    }
                    
                    if (tlv.type != imgTlvType.SHA256.code || UInt32(tlv.len) != NewtImageHeader.kHashSize) {
                        dataOff += NewtImageHeader.kTlvSize + UInt32(tlv.len)
                        continue
                    }
                    
                    dataOff += NewtImageHeader.kTlvSize
                    if (dataOff + NewtImageHeader.kHashSize > dataEnd) {
                        return (ver, Data())
                    }
                    
                    hash = data.subdata(in: Int(dataOff)..<Int(dataOff)+Int(NewtImageHeader.kHashSize))
                }
            }
            
            return (ver, hash)
        }
    }
}
