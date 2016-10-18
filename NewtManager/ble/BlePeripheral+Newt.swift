//
//  NewtManager.swift
//  NewtManager
//
//  Created by Antonio García on 14/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth
import SwiftyJSON

extension BlePeripheral {
    // Costants
    static let kNewtServiceUUID = CBUUID(string: "8D53DC1D-1DB7-4CD3-868B-8A527460AA84")
    private static let kNewtCharacteristicUUID = CBUUID(string:"DA2E7828-FBCE-4E01-AE9E-261174997C48")
    
    //
    typealias NewtRequestCompletionHandler = ((_ data: Any?, _ error: Error?) -> Void)
    typealias NewtRequestProgressHandler = ((_ progress: Float) -> Bool)
    
    // MARK: - Custom properties
    private struct CustomPropertiesKeys {
        static var newtCharacteristic: CBCharacteristic?
        static var newtCharacteristicWriteType: CBCharacteristicWriteType?
        static var newtRequestsQueue: CommandQueue<NmgrRequest>?
    }
    
    private var newtCharacteristic: CBCharacteristic? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristic) as! CBCharacteristic?
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristic, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    
    private var newtCharacteristicWriteType: CBCharacteristicWriteType? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristicWriteType) as! CBCharacteristicWriteType?
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristicWriteType, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        
    }
    
    private var newtRequestsQueue: CommandQueue<NmgrRequest> {
        get {
            var queue = objc_getAssociatedObject(self, &CustomPropertiesKeys.newtRequestsQueue) as! CommandQueue<NmgrRequest>?
            if queue == nil {
                queue = CommandQueue<NmgrRequest>()
                queue!.executeHandler = newtExecuteRequest
                self.newtRequestsQueue = queue!
            }
            return queue!
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.newtRequestsQueue, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    
    // MARK: - Message format
    
    enum NewtError: Error {
        case invalidCharacteristic
        case enableNotifyFailed
        case receivedResponseIsNotAPacket
        case receivedResponseIsNotAJson(Error?)
        case receivedResponseJsonMissingFields
        case receviedResponseJsonInvalidValues
        case receivedResultNotOk(String)
        case internalError
        case updateImageInvalid
        case imageInvalid
        
        var description: String {
            switch self {
            case .invalidCharacteristic: return "Newt characteristic is invalid"
            case .enableNotifyFailed: return "Cannot enable notification on Newt characteristic"
            case .receivedResponseIsNotAPacket: return "Received response is not a packet"
            case .receivedResponseIsNotAJson(let error): return "Received invalid Json: \(error?.localizedDescription ?? "")"
            case .receivedResponseJsonMissingFields: return "Received Json with missing fields"
            case .receviedResponseJsonInvalidValues: return "Received Json with invalid values"
            case .receivedResultNotOk(let message): return "Received incorrect result: \(message)"
            case .internalError: return "Internal error"
            case .updateImageInvalid: return "Upload image is invalid"
            case .imageInvalid: return "Image invalid"
            }
        }
    }
    
    // Nmgr Flags/Opcode/Group/Id Enums
    private enum Flags: UInt8 {
        case Default = 0
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum OpCode: UInt8 {
        case Read       = 0
        case ReadResp   = 1
        case Write      = 2
        case WriteRsp   = 3
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum Group: UInt16 {
        case Default    = 0
        case Image      = 1
        case Stats      = 2
        case Config     = 3
        case Logs       = 4
        case Crash      = 5
        case Peruser    = 64
        
        var code: UInt16 {
            return rawValue
        }
    }
    
    private enum GroupImage: UInt8 {
        case List       = 0
        case Upload     = 1
        case Boot       = 2
        case File       = 3
        case List2      = 4
        case Activate   = 5
        case Corelist   = 6
        case Coreload   = 7
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum GroupDefault: UInt8 {
        case Echo           = 0
        case ConsEchoCtrl   = 1
        case Taskstats      = 2
        case Mpstats        = 3
        case DatetimeStr    = 4
        case Reset          = 5
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum ReturnCode: UInt16 {
        case EOk        = 0
        case EUnknown   = 1
        case ENomem     = 2
        case EInval     = 3
        case ETimeout   = 4
        case ENonent    = 5
        case EPeruser   = 256
        
        var description: String {
            switch self {
            case .EOk: return "Success"
            case .EUnknown: return "Unknown Error: Command might not be supported"
            case .ENomem:  return "Out of memory"
            case .EInval: return "Device is in invalid state"
            case .ETimeout: return "Operation Timeout"
            case .ENonent: return "Enoent"
            case .EPeruser: return "Peruser"
            }
        }
        
        var code: UInt16 {
            return rawValue
        }
    }
    
    private struct Packet {
        var op: OpCode
        var flags: Flags
        var len: UInt16
        var group: Group
        var seq: UInt8
        var id: UInt8
        var data: Data
        
        init?(op: OpCode, flags: Flags, len: UInt16, group: Group, seq:UInt8, id: UInt8, data: Data = Data()) {
            self.op    = op
            self.flags = flags
            self.len   = len
            self.group = group
            self.seq   = seq
            self.id    = id
            self.data  = data
        }
        
        func encode(data: Data?) -> Data {
            struct ArchivedPacket {
                var op   : UInt8
                var flags: UInt8
                var len  : UInt16
                var group: UInt16
                var seq  : UInt8
                var id   : UInt8
            }
            
            let dataLen = UInt16(data?.count ?? 0)
            var archivedNmgrPacket = ArchivedPacket(op: op.code, flags: flags.code, len: dataLen.byteSwapped, group: group.code.byteSwapped, seq: seq, id: id)
            
            let packetSize = MemoryLayout.size(ofValue: archivedNmgrPacket)
            var packet = Data(capacity: packetSize)
            packet.append(UnsafeBufferPointer(start: &archivedNmgrPacket, count: 1))
            if let data = data {
                packet.append(data)
            }
            
            return packet
        }
    }
    
    enum NmgrCommand {
        case list
        case taskStats
        case boot
        case upload(imageData: Data)
        case bootImage(data: Data)
        case bootVersion(version: String)
        case reset
    }
    
    private struct NmgrRequest {
        var command: NmgrCommand
        var progress: NewtRequestProgressHandler?
        var completion: NewtRequestCompletionHandler?
        
        init(command: NmgrCommand, progress: NewtRequestProgressHandler?, completion: NewtRequestCompletionHandler?) {
            self.command = command
            self.progress = progress
            self.completion = completion
        }
        
        static let uploadPacket = Packet(op: OpCode.Write, flags: Flags.Default, len: 0, group: Group.Image, seq: 0, id: GroupImage.Upload.code)!

        var packet: Packet {
            var packet: Packet
            
            switch command {
            case .list:
                packet = Packet(op: OpCode.Read, flags: Flags.Default, len: 0, group: Group.Image, seq: 0, id: GroupImage.List.code)!
                
            case .taskStats:
                packet = Packet(op: OpCode.Read, flags: Flags.Default,  len: 0, group: Group.Default, seq: 0, id: GroupDefault.Taskstats.code)!
                
            case .boot:
                packet = Packet(op: OpCode.Read, flags: Flags.Default,  len: 0, group: Group.Image, seq: 0, id: GroupImage.Boot.code)!
                
            case .upload:
                packet = NmgrRequest.uploadPacket
                
            case .bootImage:
                packet = Packet(op: OpCode.Write, flags: Flags.Default, len: 0, group: Group.Image, seq: 0, id: GroupImage.Activate.code)!
                
            case .bootVersion:
                packet = Packet(op: OpCode.Write, flags: Flags.Default, len: 0, group: Group.Image, seq: 0, id: GroupImage.Boot.code)!
                
            case .reset:
                packet = Packet(op: OpCode.Write, flags: Flags.Default, len: 0, group: Group.Default, seq: 0, id: GroupDefault.Reset.code)!
            }
            
            return packet
        }
        
        var description: String {
            switch command {
            case .list:
                return "List"
            case .taskStats:
                return "TaskStats"
            case .boot:
                return "Boot"
            case .upload:
                return "Upload"
            case .bootImage:
                return "Boot from image"
            case .bootVersion(let version):
                return "Boot version \(version)"
            case .reset:
                return "Reset"
            }
        }
    }

    
    private struct NmgrResponse {
        var packet: Packet
        
        init?(_ data: Data) {
            packet = NmgrResponse.decode(data: data)
        }
        
        var description: String {
            return "Nmgr Response (Op Code = \(packet.op.rawValue) Group = \(packet.group.rawValue) Id = \(packet.id))"
        }
        
        static func decode(data: Data) -> Packet {
            var op: UInt8
            var flags: UInt8
            var bytesReceived: UInt16
            var group: UInt16
            var seq: UInt8
            var id: UInt8
            var pktData: Data
            
            op = data.scanValue(start: 0, length: 1)
            flags = data.scanValue(start: 1, length: 1)
            bytesReceived = data.scanValue(start: 2, length: 2)
            bytesReceived = (UInt16(bytesReceived)).byteSwapped
            group = data.scanValue(start: 4, length: 2)
            group = (UInt16(group)).byteSwapped
            seq = data.scanValue(start: 6, length: 1)
            id = data.scanValue(start: 7, length: 1)
            
            let kDataOffset = 8
            if Int(bytesReceived) > data.count-kDataOffset {
                DLog("Warning: received lenght is bigger that packet size")
                bytesReceived = min(bytesReceived, UInt16(data.count-kDataOffset))
            }
            
            pktData = data.subdata(in: kDataOffset..<kDataOffset+Int(bytesReceived))
            
            DLog("Received Nmgr Notification Response: Op:\(op) Flags:\(flags) Len:\(bytesReceived) Group:\(group) Seq:\(seq) Id:\(id) data:\(pktData)")
            
            return Packet(op: OpCode(rawValue: op)!, flags:Flags(rawValue: flags)!, len: bytesReceived, group: Group(rawValue: group)!, seq: seq, id: id, data: pktData)!
        }
    }
    
    
    // MARK: - Setup
    func setupNewtManager(completion: ((Error?) -> Void)?) {
        
        // Get newt communications characteristic
        characteristic(uuid: BlePeripheral.kNewtCharacteristicUUID, serviceUuid: BlePeripheral.kNewtServiceUUID) { [unowned self] (characteristic, error) in
            if let characteristic = characteristic, error == nil {
                // Get characteristic info
                self.newtCharacteristic = characteristic
                self.newtCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse:.withResponse
                
                // Enable notifications
                self.setNotify(for: characteristic, enabled: true, handler: { [unowned self] (error) in
                    self.newtReceivedData(data: characteristic.value, error: error)
                    }, completion: { error in
                        completion?(error != nil ? error : (characteristic.isNotifying ? nil : NewtError.enableNotifyFailed))
                })
            }
            else {
                completion?(error != nil ? error : NewtError.invalidCharacteristic)
            }
        }
    }
    
    var isNewtManagerReady: Bool {
        return newtCharacteristic != nil && newtCharacteristicWriteType != nil
    }
    
    func newtManagerDisconnected() {
        newtCharacteristic = nil
        newtCharacteristicWriteType = nil
        newtRequestsQueue.removeAll()
    }
    
    
    // MARK: - Send Request
    func newtRequest(with command: NmgrCommand, progress: NewtRequestProgressHandler? = nil, completion: NewtRequestCompletionHandler?) {
        
        let request = NmgrRequest(command: command, progress: progress, completion: completion)
        newtRequestsQueue.append(request)
    }

   
    // MARK: - Execute Request
    private func newtExecuteRequest(request: NmgrRequest) {
        guard  let newtCharacteristic = newtCharacteristic, let newtCharacteristicWriteType = newtCharacteristicWriteType else {
            DLog("Command Error: Peripheral not configured. Use setup()")
            request.completion?(nil, NewtError.invalidCharacteristic)
            newtRequestsQueue.next()
            return
        }
        
        var data: Data?
        switch request.command {
        case .upload(let imageData):
            data = newtUpload(imageData: imageData, progress: request.progress, completion: request.completion)
            
        case .bootImage(let imageData):
            data = newtBoot(imageData: imageData, packet: request.packet)
            
        case .bootVersion(let version):
            data = newtBoot(version: version, packet: request.packet)
            
        default:
            data = request.packet.encode(data: nil)
        }
        
        if let writeData = data {
            DLog("Command: \(request.description) [\(hexDescription(data: writeData))]")
            
            write(data: writeData, for: newtCharacteristic, type: newtCharacteristicWriteType) { [weak self] error in
                if error != nil {
                    DLog("Error: \(error!)")
                    request.completion?(nil, error)
                    self?.newtRequestsQueue.next()
                }
            }
        }
    }

    // MARK: Boot
    private func newtBoot(imageData: Data, packet: Packet) -> Data {
        let (_, buildId) = BlePeripheral.readInfo(imageData: imageData)
        
        let buildIdBase64 = buildId.base64EncodedString(options: [])
        let dataDictionary: [String: Any] = [ "test": buildIdBase64]
        let encodedData = encodeJson(dataDictionary: dataDictionary)
        
        let requestPacketData = packet.encode(data: encodedData)
        return requestPacketData
    }
    
    
    private func newtBoot(version: String, packet: Packet) -> Data {
        let dataDictionary: [String: Any] = [ "test": version]
        let encodedData = encodeJson(dataDictionary: dataDictionary)
        
        let requestPacketData = packet.encode(data: encodedData)
        return requestPacketData
    }
    // MARK: Upload
    private func newtUpload(imageData: Data, progress: NewtRequestProgressHandler?, completion: NewtRequestCompletionHandler?) -> Data? {
        guard imageData.count >= 32 else {
            completion?(nil, NewtError.updateImageInvalid)
            newtRequestsQueue.next()
            return nil
        }
        
        // Start uploading the first packet (it will continue uploading packets step by step each time a notification is received)
        return newtUploadPacket(from: imageData, offset: 0, progress: progress, completion: completion)
    }
 
    private func newtUploadPacket(from imageData: Data, offset dataOffset: Int, progress: NewtRequestProgressHandler?, completion: NewtRequestCompletionHandler?) -> Data? {
  
        // Update progress
        var isCancelled = false
        if let progress = progress {
            let currentProgress = Float(dataOffset) / Float(imageData.count)
            isCancelled = progress(currentProgress)
        }
        
        var packetData: Data? = nil
        if isCancelled || imageData.count - dataOffset <= 0 {      // Finished
            completion?(nil, nil)
            newtRequestsQueue.next()
        }
        else {                                      // Create packet data
            packetData = createUploadPacket(with: imageData, packetOffset: dataOffset)
        }
 
        return packetData
    }
    
    private func createUploadPacket(with firmwareData: Data, packetOffset: Int) -> Data{
        
        // Calculate bytes to send
        let kMaxPacketSize = 76
        
        let firmwareSize = firmwareData.count
        let remainingBytes = firmwareSize - packetOffset
        
        var bytesToSend: Int
        if remainingBytes >= kMaxPacketSize {
            bytesToSend = kMaxPacketSize
        }
        else {
            bytesToSend = remainingBytes % kMaxPacketSize
        }
        
        // Create data to send
        let packetData = firmwareData.subdata(in: packetOffset..<packetOffset+bytesToSend)

        // Encode packetData
        let packetDataBase64 = packetData.base64EncodedString(options: [])
        var dataDictionary: [String: Any] = ["off": packetOffset, "data": packetDataBase64]
        if packetOffset == 0 {
            dataDictionary["len"] = firmwareSize
        }
        let encodedData = encodeJson(dataDictionary: dataDictionary)
        
        /*
        if let encodedData = encodedData {
            DLog("payload: \(hexDescription(data: encodedData))")
        }*/
        
        // Create request packet
        let requestPacketData = NmgrRequest.uploadPacket.encode(data: encodedData)
        
        return requestPacketData
    }

    private func encodeJson(dataDictionary: Dictionary<String, Any>) -> Data? {
        let json = JSON(dataDictionary)
        
        #if DEBUG
            let payload = json.rawString(.utf8, options: [])
            DLog("JSON payload: \(payload != nil ? payload!: "<empty>")")
        #endif
        
        var encodedData: Data?
        do {
            encodedData = try json.rawData(options: [])
        }
        catch {
            DLog("Error encoding packet: \(error)")
        }
        
        return encodedData
    }
    
    
    // MARK: - Receive Response
    private func newtReceivedData(data: Data?, error: Error?) {
        guard let data = data, error == nil else {
            DLog("Error reading newt data: \(error)")
            responseError(error: error)
            return
        }
        
        guard let response = NmgrResponse(data) else {
            DLog("Error parsing newt data: \(decimalDescription(data: data))")
            responseError(error: NewtError.receivedResponseIsNotAPacket)
            return
        }
        
        if let command = newtRequestsQueue.first()?.command {
            
            // Decode json
            let json = JSON(data: response.packet.data)
            
            #if DEBUG
                let payload = json.rawString(.utf8, options: [])
                DLog("Received JSON payload: \(payload != nil ? payload!: "<empty>")")
            #endif
            
            
            // Check json validity if needed
            switch command {
            case .reset:        // Reset response is not a JSON
                break
                
            default:
                guard json.error == nil, !json.isEmpty else {
                    responseError(error: NewtError.receivedResponseIsNotAJson(json.error))
                    return
                }
            }
            
            // Parse response
            switch command {
            case .list:
                parseResponseList(json)
                
            case .taskStats:
                parseResponseTaskStats(json)
                
            case .boot:
                parseResponseBoot(json)
                
            case .upload(let imageData):
                parseResponseUploadImage(json, imageData: imageData)
                
            case .bootImage, .bootVersion:
                parseBasicJsonResponse(json)
                
            case .reset:
                parseBasicResponse()
            }
        }
        else {
            DLog("Error: newtReadData with no command")
        }
    }
    
    
    // MARK: List
    private func parseResponseList(_ json: JSON) {
        defer {
            newtRequestsQueue.next()
        }
        
        let images = json["images"].arrayValue.map{$0.stringValue}
        
        let completionHandler = newtRequestsQueue.first()?.completion
        completionHandler?(images, nil)
    }
    

    // MARK: TaskStats
    private func parseResponseTaskStats(_ json: JSON) {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        guard verifyResponseCode(json, completionHandler: completionHandler) else {
            return
        }
        
        let tasksJson = json["tasks"].arrayValue.map({$0.stringValue})
        
        completionHandler?(tasksJson, nil)
    }
    
    // MARK: Boot
    private func parseResponseBoot(_ json: JSON) {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        guard verifyResponseCode(json, completionHandler: completionHandler) else {
            return
        }
        
        let tasksJson = json["boot"].arrayValue.map({$0.stringValue})
        
        completionHandler?(tasksJson, nil)
    }

    
     // MARK: Basic Command (Activate)
    private func parseBasicJsonResponse(_ json: JSON) {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        guard verifyResponseCode(json, completionHandler: completionHandler) else {
            return
        }

        completionHandler?(nil, nil)
    }
    
    private func parseBasicResponse() {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        completionHandler?(nil, nil)
    }
    
    // MARK: Upload Image
    private func parseResponseUploadImage(_ json: JSON, imageData: Data) {
        
        let request = newtRequestsQueue.first()
        
        guard verifyResponseCode(json, completionHandler: request?.completion) else {
            newtRequestsQueue.next()
            return
        }

        guard let newtCharacteristic = newtCharacteristic, let newtCharacteristicWriteType = newtCharacteristicWriteType else {
            DLog("Command Error: characteristic no longer valid")
            request?.completion?(nil, NewtError.invalidCharacteristic)
            newtRequestsQueue.next()
            return
        }
        
        let offset = json["off"].intValue
        if let writeData = newtUploadPacket(from: imageData, offset: offset, progress: request?.progress, completion: request?.completion) {
            
            write(data: writeData, for: newtCharacteristic, type: newtCharacteristicWriteType) { [weak self] error in
                if error != nil {
                    DLog("Error: \(error!)")
                    request?.completion?(nil, error)
                    self?.newtRequestsQueue.next()
                }
            }
        }
    }
    
    // MARK: Utils
    private func verifyResponseCode(_ json: JSON, completionHandler: NewtRequestCompletionHandler?) -> Bool {
        
        guard let returnCodeRaw = json["rc"].uInt16 else {
            DLog("parseResponse Error: rc not found")
            completionHandler?(nil, NewtError.receivedResponseJsonMissingFields)
            return false
        }
        
        guard let returnCode = ReturnCode(rawValue: returnCodeRaw) else {
            DLog("parseResponse Error: rc invalid value")
            completionHandler?(nil, NewtError.receviedResponseJsonInvalidValues)
            return false
        }
        
        guard returnCode == ReturnCode.EOk else {
            DLog("parseResponse Error: \(returnCode.description)")
            completionHandler?(nil, NewtError.receivedResultNotOk(returnCode.description))
            return false
        }
        
        return true
    }
    
    private func responseError(error: Error?) {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        completionHandler?(nil, error)
    }
    
    
    // MARK: - Image Structures and functions
    private struct NewtImageHeader {
        static let kHeaderSize: UInt16    = 32
        static let kMagic: UInt32         = 0x96f3b83c
        static let kMagicNone: UInt32     = 0xffffffff
        static let kHashSize: UInt32      = 32
        static let kTlvSize: UInt32       = 4
    }
    
    private enum imgFlags : UInt32 {
        case SHA256                 = 0x00000002    // Image contains hash TLV
        case PKCS15_RSA2048_SHA256  = 0x00000004    // PKCS15 w/RSA and SHA
        case ECDSA224_SHA256        = 0x00000008    // ECDSA256 over SHA256
        
        var code:UInt32 {
            return rawValue
        }
    }
    
    
    // Image trailer TLV types.
    
    private enum imgTlvType : UInt8 {
        case SHA256   = 1 // SHA256 of image hdr and body
        case RSA2048  = 2 // RSA2048 of hash output
        case ECDSA224 = 3 // ECDSA of hash output
        
        var code:UInt8 {
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
        var magic:UInt32
        var tlvSize:UInt16  // Trailing TLVs
        var keyId:UInt8
        //uint8_t  _pad1;
        var hdrSize:UInt16
        //uint16_t _pad2;
        var imgSize:UInt32  // Does not include header.
        var flags:UInt32
        var ver: imgVersion
        //uint32_t _pad3;
        
        init?(magic:UInt32, tlvSize:UInt16,
              keyId:UInt8, hdrSize:UInt16,
              imgSize:UInt32, flags:UInt32,
              ver:imgVersion) {
            
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
    
    static func readInfo(imageData data: Data) -> (vesion: imgVersion, hash: Data) {
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
    
    // MARK: - Utils
    static func newtShowErrorAlert(from controller: UIViewController, title: String? = "Error", error: Error) {
        let message: String?
        if let newtError = error as? BlePeripheral.NewtError {
            message = newtError.description
        }
        else {
            message = error.localizedDescription
        }
        
        showErrorAlert(from: controller, title: title, message: message)
    }

}

// MARK: - Data Scan
extension Data {
    func scanValue<T>(start: Int, length: Int) -> T {
        return self.subdata(in: start..<start+length).withUnsafeBytes { $0.pointee }
    }
}

