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
    
    // Types
    typealias NewtRequestCompletionHandler = ((_ data: Any?, _ error: Error?) -> Void)
    typealias NewtRequestProgressHandler = ((_ progress: Float) -> Bool)    // Return value indicates if the operation should be cancelled
    
    // MARK: - Custom properties
    private struct CustomPropertiesKeys {
        static var newtCharacteristic: CBCharacteristic?
        static var newtCharacteristicWriteType: CBCharacteristicWriteType?
        static var newtRequestsQueue: CommandQueue<NmgrRequest>?
        static var newtResponseCache: Data?
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
    
    private var newtResponseCache: Data {
        get {
            var data = objc_getAssociatedObject(self, &CustomPropertiesKeys.newtResponseCache) as! Data?
            if data == nil {
                data = Data()
                self.newtResponseCache = data!
            }
            return data!
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.newtResponseCache, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // MARK: - Message format
    private enum Flags: UInt8 {
        case none               = 0
        case responseComplete   = 1
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum OpCode: UInt8 {
        case read           = 0
        case readResponse   = 1
        case write          = 2
        case writeResponse  = 3
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum Group: UInt16 {
        case `default`    = 0
        case image      = 1
        
        /*
        case stats      = 2
        case config     = 3
        case logs       = 4
        case crash      = 5
        case peruser    = 64
        */
        var code: UInt16 {
            return rawValue
        }
    }
    
    private enum GroupImage: UInt8 {
        case list       = 0
        case upload     = 1

        /*
        case Boot       = 2
        case File       = 3
        case List2      = 4
        case Activate   = 5
        case Corelist   = 6
        case Coreload   = 7
        */
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum GroupDefault: UInt8 {
        case echo           = 0
        case taskStats      = 2
        
        /*
        case ConsEchoCtrl   = 1
        case Mpstats        = 3
        case DatetimeStr    = 4
 */
        case reset          = 5
        
        var code: UInt8 {
            return rawValue
        }
    }
    
    private enum ReturnCode: UInt16 {
        case ok        = 0
        case unknown   = 1
        case nomem     = 2
        case inval     = 3
        case timeout   = 4
        case nonent    = 5
        case peruser   = 256
        
        var description: String {
            switch self {
            case .ok: return "Success"
            case .unknown: return "Unknown Error: Command might not be supported"
            case .nomem:  return "Out of memory"
            case .inval: return "Device is in invalid state"
            case .timeout: return "Operation Timeout"
            case .nonent: return "Enoent"
            case .peruser: return "Peruser"
            }
        }
        
        var code: UInt16 {
            return rawValue
        }
    }
    
    private struct Packet {
        var op: OpCode
        var flags: Flags
        var len: UInt16 {
            return UInt16(data.count)
        }
        var group: Group
        var seq: UInt8
        var id: UInt8
        var data: Data
        
        init(op: OpCode, flags: Flags, group: Group, seq:UInt8, id: UInt8, data: Data = Data()) {
            self.op    = op
            self.flags = flags
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
        case imageList
        case imageTest(hash: Data)
        case imageConfirm(hash: Data?)
        case upload(imageData: Data)
        case taskStats
        case reset
        case echo(message: String)
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
        
        static let uploadPacket = Packet(op: OpCode.write, flags: Flags.none,  group: Group.image, seq: 0, id: GroupImage.upload.code)
        
        var packet: Packet {
            var packet: Packet
            
            switch command {
            case .imageList, .imageTest, .imageConfirm:
                packet = Packet(op: OpCode.read, flags: Flags.none, group: Group.image, seq: 0, id: GroupImage.list.code)
                
            case .upload:
                packet = NmgrRequest.uploadPacket
                
            case .taskStats:
                packet = Packet(op: OpCode.read, flags: Flags.none, group: Group.default, seq: 0, id: GroupDefault.taskStats.code)

            case .reset:
                packet = Packet(op: OpCode.write, flags: Flags.none, group: Group.default, seq: 0, id: GroupDefault.reset.code)
                
            case .echo:
                packet = Packet(op: OpCode.write, flags: Flags.none, group: Group.default, seq: 0, id: GroupDefault.echo.code)
            }
            
            return packet
        }
        
        var description: String {
            switch command {
            case .imageList:
                return "Image List"
            case .imageTest:
                return "Image Test"
            case .imageConfirm:
                return "Image Confirm"
            case .upload:
                return "Upload"
            case .taskStats:
                return "TaskStats"
            case .reset:
                return "Reset"
            case .echo:
                return "Echo"
            }
        }
    }
    
    private struct NmgrResponse {
        var packet: Packet!
        
        var description: String {
            return packet != nil ? "Nmgr Response (Op Code = \(packet!.op.rawValue) Group = \(packet!.group.rawValue) Id = \(packet!.id))" : "<undefined packet>"
        }
        
        init?(_ data: Data) {
            guard let decodedPacket = NmgrResponse.decode(data: data) else {
                return nil
            }
            
            packet = decodedPacket
        }
        
        private static func decode(data: Data) -> Packet? {
            let op: UInt8 = data.scanValue(start: 0, length: 1)
            let flagsValue: UInt8 = data.scanValue(start: 1, length: 1)
            var bytesReceived: UInt16 = data.scanValue(start: 2, length: 2)
            bytesReceived = (UInt16(bytesReceived)).byteSwapped
            var groupValue: UInt16 = data.scanValue(start: 4, length: 2)
            groupValue = (UInt16(groupValue)).byteSwapped
            let seq: UInt8 = data.scanValue(start: 6, length: 1)
            let id: UInt8 = data.scanValue(start: 7, length: 1)
            
            let kDataOffset = 8
            if Int(bytesReceived) > data.count-kDataOffset {
                DLog("Warning: received lenght is bigger that packet size")
                bytesReceived = min(bytesReceived, UInt16(data.count-kDataOffset))
            }
            
            let pktData = data.subdata(in: kDataOffset..<kDataOffset+Int(bytesReceived))
            
            DLog("Received Nmgr Notification Response: Op:\(op) Flags:\(flagsValue) Len:\(bytesReceived) Group:\(groupValue) Seq:\(seq) Id:\(id) data:\(pktData)")
            guard  let opcode = OpCode(rawValue: op), let flags = Flags(rawValue: flagsValue), let group = Group(rawValue: groupValue) else {
                DLog("Error: invalid NmgrResponse packet values")
                return nil
            }
            
            let packet = Packet(op: opcode, flags: flags, /*len: bytesReceived, */group: group, seq: seq, id: id, data: pktData)
            if bytesReceived != packet.len {
                DLog("Warning: mismatch in packet lenght reported")
            }
            return packet
        }
    }
    
    // MARK: - Initialization
    func newtInit(completion: ((Error?) -> Void)?) {
        newtResponseCache.removeAll()
        
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
    
    var isNewtReady: Bool {
        return newtCharacteristic != nil && newtCharacteristicWriteType != nil
    }
    
    func newtDeInit(wasDisconnected: Bool) {
        // Clear all Newt specific data
        defer {
            newtCharacteristic = nil
            newtCharacteristicWriteType = nil
            newtRequestsQueue.removeAll()
            newtResponseCache.removeAll()
        }
        
        if !wasDisconnected, let characteristic = newtCharacteristic {
            // Disable notify
            setNotify(for: characteristic, enabled: false)
        }
    }
    
    // MARK: - Send Request
    func newtSendRequest(with command: NmgrCommand, progress: NewtRequestProgressHandler? = nil, completion: NewtRequestCompletionHandler?) {
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
        
        guard newtResponseCache.isEmpty else {
            DLog("Error: trying to send command while waiting for response")
            request.completion?(nil, NewtError.waitingForReponse)
            newtRequestsQueue.next()
            return
        }
        
        var data: Data?
        switch request.command {
        case let .imageTest(hash: hash):
            data = newtImageTest(hash: hash)

        case let .imageConfirm(hash: hash):
            data = newtImageConfirm(hash: hash)

        case .upload(let imageData):
            data = newtUpload(imageData: imageData, progress: request.progress, completion: request.completion)
            
        case .echo(let message):
            data = newtEcho(message: message)
  
        default:
            data = nil
        }
        
        let requestPacketData = request.packet.encode(data: data)
        
        DLog("Send Command: Op:\(request.packet.op.rawValue) Flags:\(request.packet.flags.rawValue) Len:\(data?.count ?? 0) Group:\(request.packet.group.rawValue) Seq:\(request.packet.seq) Id:\(request.packet.id) Data:[\(data != nil ? hexDescription(data: data!):"")]")
        
        write(data: requestPacketData, for: newtCharacteristic, type: newtCharacteristicWriteType) { [weak self] error in
            if error != nil {
                DLog("Error: \(error!)")
                request.completion?(nil, error)
                self?.newtRequestsQueue.next()
            }
            
        }
    }
    
    // MARK: ImageTest
    private func newtImageTest(hash: Data) -> Data? {
        //let hashBase64 = hash.base64EncodedString(options: [])
        let dataDictionary: [String: Any] = ["confirm": false, "hash": hash]
        let encodedData = encodeCbor(dataDictionary: dataDictionary)
        
        return encodedData
    }

    // MARK: ImageConfirm
    private func newtImageConfirm(hash: Data?) -> Data? {
        
        var dataDictionary: [String: Any] = ["confirm": true]
        if let hash = hash {
            dataDictionary["hash"] =  hash
        }
        else {
            dataDictionary["hash"] = NSNull()
        }
        
        let encodedData = encodeCbor(dataDictionary: dataDictionary)
        
        return encodedData
    }
    
    // MARK: Echo
    private func newtEcho(message: String) -> Data? {
        let dataDictionary: [String: Any] = ["d": message]
        let encodedData = encodeCbor(dataDictionary: dataDictionary)
        
        return encodedData
    }
    
    // MARK: Upload
    private func newtUpload(imageData: Data, progress: NewtRequestProgressHandler?, completion: NewtRequestCompletionHandler?) -> Data? {
        guard imageData.count >= 32 else {
            completion?(nil, NewtError.updateImageInvalid)
            newtRequestsQueue.next()
            return nil
        }
        
        // Start uploading the first packet (it will continue uploading packets step by step each time a notification is received)
        return newtUploadPacketData(from: imageData, offset: 0, progress: progress, completion: completion)
    }
    
    private func newtUploadPacketData(from imageData: Data, offset dataOffset: Int, progress: NewtRequestProgressHandler?, completion: NewtRequestCompletionHandler?) -> Data? {
        
        // Update progress
        var isCancelled = false
        if let progress = progress {
            let currentProgress = Float(dataOffset) / Float(imageData.count)
            isCancelled = progress(currentProgress)
        }
        
        var packetData: Data? = nil
        
        if isCancelled {                                // Cancelled
            completion?(nil, NewtError.userCancelled)
            newtRequestsQueue.next()
        }
        else if imageData.count - dataOffset <= 0 {     // Finished
            completion?(nil, nil)
            newtRequestsQueue.next()
        }
        else {                                          // Create packet data
            packetData = createUploadPacketData(with: imageData, packetOffset: dataOffset)
        }
        
        return packetData
    }
    
    private func createUploadPacketData(with firmwareData: Data, packetOffset: Int) -> Data? {
        
        // Calculate bytes to send
        //let kMaxPacketSize = 56 // 76
        let isFirstPacket = packetOffset == 0
        let maxPacketSize =  153 - (isFirstPacket ? 7:0)

        let firmwareSize = firmwareData.count
        let remainingBytes = firmwareSize - packetOffset
        
        var bytesToSend: Int
        if remainingBytes >= maxPacketSize {
            bytesToSend = maxPacketSize
        }
        else {
            bytesToSend = remainingBytes % maxPacketSize
        }
        
        // Create data to send
        let packetData = firmwareData.subdata(in: packetOffset..<packetOffset+bytesToSend)
        var dataDictionary: [String: Any] = ["off": packetOffset, "data": packetData]
        if isFirstPacket {
            dataDictionary["len"] = firmwareSize
        }
        let encodedData = encodeCbor(dataDictionary: dataDictionary)
        
        return encodedData
    }
    
    private func encodeCbor(dataDictionary: Dictionary<String, Any>) -> Data? {
        guard let cbor = CBOR(rawValue: dataDictionary) else {
            DLog("Error generating CBOR")
            return nil
        }
        
        DLog("------");
        DLog("Prepare CBOR payload: \(cbor.description)")
        
        var encodedData: Data?
        do {
            encodedData = try CBOREncoder().encodeItemAsData(cbor: cbor)
        }
        catch {
            DLog("Error encoding packet: \(error)")
        }
        
        return encodedData
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
        
        guard let command = newtRequestsQueue.first()?.command else {
            DLog("Warning: newtReadData with no command")
            return
        }
        
        // Read data
        #if DEBUG
            DLog("Received data: \(hexDescription(data: response.packet.data))")
        #endif
        
        
        newtResponseCache.append(response.packet.data)
        
        guard response.packet.flags == .responseComplete else {
            DLog("waiting next packet...")
            return
        }
        
        // Decode CBOR
        var cbor: CBOR?
        do {
            cbor = try CBORDecoder(data: newtResponseCache).decodeItem()
        }
        catch {
            DLog("Error: Can't decode CBOR")
        }
        
        // Remove cached data
        newtResponseCache.removeAll()
        
        // Process response
        if let cbor = cbor {
            DLog("Received CBOR: \(cbor)")
            
            // Parse response
            switch command {
            case .imageList, .imageTest, .imageConfirm:
                parseResponseImageList(cbor: cbor)
            case .echo:
                parseEcho(cbor: cbor)
            case .upload(let imageData):
                parseResponseUploadImage(cbor: cbor, imageData: imageData)
            case .taskStats:
                parseResponseTaskStats(cbor: cbor)
            default:
                parseBasicResponse(cbor: cbor)
            }
        }
        else {
            DLog("Error: CBOR is nil")
        }
    }
    
    // MARK: List
 
    private func parseResponseImageList(cbor: CBOR) {
        defer {
            newtRequestsQueue.next()
        }
        
        var images = [NewtImage]()
        
        // Decode CBOR response
        let imagesCbor = cbor["images"]
        for imageCbor in imagesCbor.arrayValue {
            let slot = imageCbor["slot"].intValue
            let version = imageCbor["version"].stringValue
            let confirmed = imageCbor["confirmed"].boolValue
            let pending = imageCbor["pending"].boolValue
            let active = imageCbor["active"].boolValue
            let bootable = imageCbor["bootable"].boolValue
            let hash = imageCbor["hash"].dataValue
            
            let image = NewtImage(slot: slot, version: version, isConfirmed: confirmed, isPending: pending, isActive: active, isBootable: bootable, hash: hash)
            images.append(image)
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        completionHandler?(images, nil)
    }
    
       // MARK: Echo
    private func parseEcho(cbor: CBOR) {
        defer {
            newtRequestsQueue.next()
        }

        let echoResponse = cbor["r"].stringValue
        
        let completionHandler = newtRequestsQueue.first()?.completion
        completionHandler?(echoResponse, nil)
    }
    
    // MARK: TaskStats
    private func parseResponseTaskStats(cbor: CBOR) {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        guard verifyResponseCode(cbor: cbor, completionHandler: completionHandler) else {
            return
        }

        let tasksCbor = cbor["tasks"]//.dictionary
        
        completionHandler?(tasksCbor, nil)
    }
    
    // MARK: Basic Command
    private func parseBasicResponse(cbor: CBOR) {
        defer {
            newtRequestsQueue.next()
        }
        
        let completionHandler = newtRequestsQueue.first()?.completion
        guard verifyResponseCode(cbor: cbor, completionHandler: completionHandler) else {
            return
        }
        
        completionHandler?(nil, nil)
    }
    
    // MARK: Upload Image
    
    private func parseResponseUploadImage(cbor: CBOR, imageData: Data) {
        
        let request = newtRequestsQueue.first()
        
        guard verifyResponseCode(cbor: cbor, completionHandler: request?.completion) else {
            newtRequestsQueue.next()
            return
        }
        
        guard let newtCharacteristic = newtCharacteristic, let newtCharacteristicWriteType = newtCharacteristicWriteType else {
            DLog("Command Error: characteristic no longer valid")
            request?.completion?(nil, NewtError.invalidCharacteristic)
            newtRequestsQueue.next()
            return
        }

        
        let offset = cbor["off"].intValue
        if let writeData = newtUploadPacketData(from: imageData, offset: offset, progress: request?.progress, completion: request?.completion) {
            
            let requestPacketData = NmgrRequest.uploadPacket.encode(data: writeData)
            
            DLog("Send Command: Op:\(NmgrRequest.uploadPacket.op.rawValue) Flags:\(NmgrRequest.uploadPacket.flags.rawValue) Len:\(writeData.count) Group:\(NmgrRequest.uploadPacket.group.rawValue) Seq:\(NmgrRequest.uploadPacket.seq) Id:\(NmgrRequest.uploadPacket.id) Data:[\(hexDescription(data: writeData))]")
            
            write(data: requestPacketData, for: newtCharacteristic, type: newtCharacteristicWriteType) { [weak self] error in
                if error != nil {
                    DLog("Error: \(error!)")
                    request?.completion?(nil, error)
                    self?.newtRequestsQueue.next()
                }
            }
        }
    }
    
    // MARK: Utils
    private func verifyResponseCode(cbor: CBOR, completionHandler: NewtRequestCompletionHandler?) -> Bool {
        
        guard let returnCodeRaw = cbor["rc"].uInt16 else {
            DLog("parseResponse Error: rc not found")
            completionHandler?(nil, NewtError.receivedResponseJsonMissingFields)
            return false
        }
        
        guard let returnCode = ReturnCode(rawValue: returnCodeRaw) else {
            DLog("parseResponse Error: rc invalid value")
            completionHandler?(nil, NewtError.receviedResponseJsonInvalidValues)
            return false
        }
        
        guard returnCode == .ok else {
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
    
    
      
    // MARK: - Utils
    static func newtShowErrorAlert(from controller: UIViewController, title: String? = "Error", error: Error) {
        let message: String?
        if let newtError = error as? NewtError {
            message = newtError.description
        }
        else {
            message = error.localizedDescription
        }
        
        showErrorAlert(from: controller, title: title, message: message)
    }
}

