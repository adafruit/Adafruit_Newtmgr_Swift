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
    typealias NewtRequestProgressHandler = ((_ progress: Float) -> Void)
    
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
    
    private enum OpDfu: UInt8 {
        case List       = 0
        case Upload     = 1
        case Boot       = 2
        case File       = 3
        case List2      = 4
        case Boot2      = 5
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
    
    private enum GroupImage: UInt8 {
        case List         = 0
        
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
            
            self.op    = OpCode.Write
            self.flags = Flags.Default
            self.len   = 0
            self.group = Group.Default
            self.seq   = 0
            self.id    = 0
            self.data  = data
            
            // Back to the passed values
            self.op    = op
            self.flags = flags
            self.len   = len
            self.group = group
            self.seq   = seq
            self.data  = data
            self.id    = id
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
            
            var archivedNmgrPacket = ArchivedPacket(op: op.code, flags: flags.code, len: len.byteSwapped, group: group.code.byteSwapped, seq: seq, id: id)
            
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
        case upload(imageData: Data)
        case activate
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
        
        var packet: Packet {
            var packet: Packet
            
            switch command {
            case .list:
                packet = Packet(op: OpCode.Read, flags: Flags.Default, len: 0, group: Group.Image, seq: 0, id: GroupImage.List.code)!
                
            case .taskStats:
                packet = Packet(op: OpCode.Read, flags: Flags.Default,  len: 0, group: Group.Default, seq: 0, id: GroupDefault.Taskstats.code)!
                
            case .upload:
                packet = NmgrRequest.uploadPacket
                
            case .activate:
                packet = Packet(op: OpCode.Write, flags: Flags.Default, len: 0, group: Group.Image, seq: 0, id: OpDfu.Boot2.code)!
                
            case .reset:
                packet = Packet(op: OpCode.Write, flags: Flags.Default, len: 0, group: Group.Default, seq: 0, id: GroupDefault.Reset.code)!
            }
            
            return packet
        }
        
        static let uploadPacket = Packet(op: OpCode.Write, flags: Flags.Default, len: 0, group: Group.Image, seq: 0, id: OpDfu.Upload.code)!
        
        var description: String {
            switch command {
            case .list:
                return "List (OpCode = \(OpCode.Read.rawValue) Group = \(Group.Image.rawValue) Id = \(OpDfu.List.code))"
            case .taskStats:
                return "TaskStats (OpCode = \(OpCode.Read.rawValue) Group = \(Group.Default.rawValue) Id = \(GroupDefault.Taskstats.code))"
            case .upload:
                return "Upload (OpCode = \(OpCode.Write.rawValue) Group = \(Group.Image.rawValue) Id = \(OpDfu.Upload.code))"
            case .activate:
                return "Activate (OpCode = \(OpCode.Write.rawValue) Group = \(Group.Image.rawValue) Id = \(OpDfu.Boot2.code))"
            case .reset:
                return "Reset (OpCode = \(OpCode.Write.rawValue) Group = \(Group.Default.rawValue) Id = \(GroupDefault.Reset.code))"
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
    
    
    // MARK: - Commands
    
    func newtRequest(with command: NmgrCommand, progress: NewtRequestProgressHandler? = nil, completion: NewtRequestCompletionHandler?) {
        
        let request = NmgrRequest(command: command, progress: progress, completion: completion)
        newtRequestsQueue.append(request)
    }
    

    // MARK: - Command Execute and Receive Data

    private func newtExecuteRequest(request: NmgrRequest) {
        
        guard  let newtCharacteristic = newtCharacteristic, let newtCharacteristicWriteType = newtCharacteristicWriteType else {
            DLog("Command Error: Peripheral not configured. Use setup()")
            request.completion?(nil, NewtError.invalidCharacteristic)
            newtRequestsQueue.next()
            return
        }
        
        switch request.command {
        case .upload(let imageData):
            newtUpload(imageData: imageData, progress: request.progress, completion: request.completion)
            
        default:
            let data = request.packet.encode(data: nil)
            DLog("Command:\(request.description) [\(hexDescription(data: data))]")
            
            write(data: data, for: newtCharacteristic, type: newtCharacteristicWriteType) { [weak self] error in
                if error != nil {
                    DLog("Error: \(error!)")
                    request.completion?(nil, error)
                    self?.newtRequestsQueue.next()
                }
            }
        }
    }

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
            let json = JSON(data: response.packet.data)
            
            #if DEBUG
                let payload = json.rawString(.utf8, options: [])
                DLog("Received JSON payload: \(payload != nil ? payload!: "<empty>")")
            #endif
            
            guard json.error == nil, !json.isEmpty else {
                responseError(error: NewtError.receivedResponseIsNotAJson(json.error))
                return
            }
            
            switch command {
            case .list:
                parseResponseList(json)
                
            case .taskStats:
                parseResponseTaskStats(json)
                
            case .upload(let imageData):
                parseResponseUploadImage(json, imageData: imageData)
                
            default:
                DLog("Not implemented")
            }
        }
        else {
            DLog("Error: newtReadData with no command")
        }
        
    }
   
    private func newtUpload(imageData: Data, progress: NewtRequestProgressHandler?, completion: NewtRequestCompletionHandler?) {

        guard imageData.count >= 32 else {
            completion?(nil, NewtError.updateImageInvalid)
            newtRequestsQueue.next()
            return
        }
        
        // Start uploading the first packet (it will continue uploading packets step by step each time a notification is received)
        newtUploadPacket(from: imageData, offset: 0, progress: progress, completion: completion)

    }
 
    private func newtUploadPacket(from imageData: Data, offset dataOffset: Int, progress: NewtRequestProgressHandler?, completion: NewtRequestCompletionHandler?) {
        guard let newtCharacteristic = newtCharacteristic, let newtCharacteristicWriteType = newtCharacteristicWriteType else {
            DLog("Command Error: Peripheral not configured. Use setup()")
            completion?(nil, NewtError.invalidCharacteristic)
            newtRequestsQueue.next()
            return
        }
        
        // Update progress
        if let progress = progress {
            let currentProgress = Float(dataOffset) / Float(imageData.count)
            progress(currentProgress)
        }

        // Create packet data
        let (packetData, dataSize) = createDfuPacket(with: imageData, packetOffset: dataOffset)
        
        
        if dataSize == 0 {
            //  Finished
            completion?(nil, nil)
            newtRequestsQueue.next()
        }
        else {
            // Write
            // DLog("peripheral.writeValue(0x\(writeData)")
            write(data: packetData, for: newtCharacteristic, type: newtCharacteristicWriteType)  { [weak self] error in
                if error != nil {
                    completion?(nil, error)
                    self?.newtRequestsQueue.next()
                }
            }
        }        
    }
    
    private func createDfuPacket(with firmwareData: Data, packetOffset: Int) -> (Data, Int) {
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
        
        let packetData = firmwareData.subdata(in: packetOffset..<packetOffset+bytesToSend)
        let encodedData = encodeData(data: packetData, packetOffset: packetOffset, firmwareSize: firmwareSize)
        
        /*
        if let encodedData = encodedData {
            DLog("payload: \(hexDescription(data: encodedData))")
        }*/
        
        var requestPacket = NmgrRequest.uploadPacket
        requestPacket.len = UInt16(encodedData?.count ?? 0)
        let requestPacketData = requestPacket.encode(data: encodedData)
        
        return (requestPacketData, bytesToSend)
    }
    
    private func encodeData(data: Data, packetOffset: Int, firmwareSize: Int) -> Data? {
        let initPktDatabase64Encoded = data.base64EncodedString(options: [])
        
        var dataDictionary: [String: Any] = ["off": packetOffset, "data": initPktDatabase64Encoded]
        if packetOffset == 0 {
            dataDictionary["len"] = firmwareSize
        }
        
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
    
    // MARK - Response
    private func parseResponseList(_ json: JSON) {
        defer {
            newtRequestsQueue.next()
        }
        
        let images = json["images"].arrayValue.map{$0.stringValue}
        
        let completionHandler = newtRequestsQueue.first()?.completion
        completionHandler?(images, nil)
    }
    
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
    
    private func parseResponseUploadImage(_ json: JSON, imageData: Data) {
        
        let request = newtRequestsQueue.first()
        
        guard verifyResponseCode(json, completionHandler: request?.completion) else {
            newtRequestsQueue.next()
            return
        }
        
        let offset = json["off"].intValue
        newtUploadPacket(from: imageData, offset: offset, progress: request?.progress, completion: request?.completion)
    }
    
    private func responseError(error: Error?) {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        completionHandler?(nil, error)
    }
}

// MARK: - Data Scan
extension Data {
    func scanValue<T>(start: Int, length: Int) -> T {
        return self.subdata(in: start..<start+length).withUnsafeBytes { $0.pointee }
    }
}

