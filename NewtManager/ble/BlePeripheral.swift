//
//  Peripheral.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/09/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class BlePeripheral: NSObject {
    
    var peripheral: CBPeripheral!
    var advertisementData: [String: Any]!
    var rssi: Int!
    var lastSeenTime: CFAbsoluteTime!
    
    var identifier: UUID {
        return peripheral.identifier
    }
    
    var name: String? {
        return peripheral.name
    }

    var state: CBPeripheralState {
        return peripheral.state
    }
    
    // Internal data
    fileprivate var notifyHandlers = [String: ((Error?) -> Void)]()                 // Nofify handlers for each service-characteristic
    fileprivate var commandQueue = CommandQueue<BleCommand>()
 

    init(peripheral: CBPeripheral, advertisementData: [String: Any], RSSI: Int) {
        super.init()
        
        self.peripheral = peripheral
        self.peripheral.delegate = self
        self.advertisementData = advertisementData
        self.rssi = RSSI
        self.lastSeenTime = CFAbsoluteTimeGetCurrent()
        
        commandQueue.executeHandler = executeCommand
    }
    
    // MARK: - Discover
    func discover(serviceUuids: [CBUUID]?, completion: ((Error?) -> Void)?) {
        let command = BleCommand(type: .discoverService, parameters: serviceUuids, completion: completion)
        commandQueue.append(command)
    }

    func discover(characteristicUuids: [CBUUID]?, service: CBService, completion: ((Error?) -> Void)?) {
        let command = BleCommand(type: .discoverCharacteristic, parameters: [characteristicUuids as Any, service], completion: completion)
        commandQueue.append(command)
    }
    
    func discover(characteristicUuids: [CBUUID]?, serviceUuid: CBUUID, completion: ((Error?) -> Void)?) {
        // Discover service
        discover(serviceUuids: [serviceUuid]) { [unowned self] error in
            guard error == nil else {
                completion?(error)
                return
            }

            guard let service = self.peripheral.services?.first(where: {$0.uuid == serviceUuid}) else {
                completion?(BleCommand.CommandError.invalidService)
                return
            }
            
            // Discover characteristic
            self.discover(characteristicUuids: characteristicUuids, service: service, completion: completion)
        }
    }
    
    // MARK: - Service
    func discoveredService(uuid: CBUUID) -> CBService? {
        let service = peripheral.services?.first(where: {$0.uuid == uuid})
        return service
    }
    
    func service(uuid: CBUUID, completion: ((CBService?, Error?) -> Void)?) {
        
        if let discoveredService = discoveredService(uuid: uuid) {                      // Service was already discovered
            completion?(discoveredService, nil)
        }
        else {
            discover(serviceUuids: [uuid], completion: { [unowned self] (error) in      // Discover service
                var discoveredService: CBService?
                if error == nil {
                    discoveredService = self.discoveredService(uuid: uuid)
                }
                completion?(discoveredService, error)
            })
        }
    }
    
    // MARK: - Characteristic
    func discoveredCharacteristic(uuid: CBUUID, service: CBService) -> CBCharacteristic? {
        let characteristic = service.characteristics?.first(where: {$0.uuid == uuid})
        return characteristic
    }
    
    func characteristic(uuid: CBUUID, service: CBService, completion: ((CBCharacteristic?, Error?) -> Void)?) {
        
        if let discoveredCharacteristic = discoveredCharacteristic(uuid: uuid, service: service) {              // Characteristic was already discovered
            completion?(discoveredCharacteristic, nil)
        }
        else {
            discover(characteristicUuids: [uuid], service: service, completion: { [unowned self] (error) in     // Discover characteristic
                var discoveredCharacteristic: CBCharacteristic?
                if error == nil {
                    discoveredCharacteristic = self.discoveredCharacteristic(uuid: uuid, service: service)
                }
                completion?(discoveredCharacteristic, error)
            })
        }
    }
    
    func characteristic(uuid: CBUUID, serviceUuid: CBUUID, completion: ((CBCharacteristic?, Error?) -> Void)?) {
        if let discoveredService = discoveredService(uuid: uuid) {                                              // Service was already discovered
            characteristic(uuid: uuid, service: discoveredService, completion: completion)
        }
        else {                                                                                                  // Discover service
            service(uuid: serviceUuid) { (service, error) in
                if let service = service, error == nil {                                                        // Discover characteristic
                    self.characteristic(uuid: uuid, service: service, completion: completion)
                }
                else {
                    completion?(nil, error != nil ? error:BleCommand.CommandError.invalidService)
                }
            }
        }
    }
    
    func setNotify(for characteristic: CBCharacteristic, enabled: Bool, handler: ((Error?) -> Void)?, completion: ((Error?) -> Void)?) {
        let command = BleCommand(type: .setNotify, parameters: [characteristic, enabled, handler as Any], completion: completion)
        commandQueue.append(command)
    }
    
    func read(data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType, completion: ((Error?) -> Void)?) {
        let command = BleCommand(type: .read, parameters: [characteristic], completion: completion)
        commandQueue.append(command)
    }
    
    func write(data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType, completion: ((Error?) -> Void)?) {
        let command = BleCommand(type: .write, parameters: [characteristic, type, data], completion: completion)
        commandQueue.append(command)
    }
    
    
    // MARK: - Command Queue
    fileprivate struct BleCommand: Equatable {
        enum CommandType {
            case discoverService
            case discoverCharacteristic
            case setNotify
            case read
            case write
        }

        enum CommandError: Error {
            case invalidService
        }
        
        var type: CommandType
        var parameters: [Any]?
        var completion: ((Error?) -> Void)?
        
        static func == (left: BleCommand, right: BleCommand) -> Bool {
            return left.type == right.type
        }
    }
    
    private func executeCommand(command: BleCommand) {

        switch command.type {
        case .discoverService:
            discoverService(with: command)
        case .discoverCharacteristic:
            discoverCharacteristic(with: command)
        case .setNotify:
            setNotify(with: command)
        case .read:
            read(with: command)
        case .write:
            write(with: command)
        }
    }
 
    fileprivate func handlerIdentifier(from characteristic: CBCharacteristic) -> String {
        return "\(characteristic.service.uuid.uuidString)-\(characteristic.uuid.uuidString)"
    }

    fileprivate func finishedExecutingCommand(error: Error?) {
        // Result Callback
        if let command = commandQueue.first() {
            command.completion?(error)
        }
        commandQueue.next()
    }
    
    // MARK: - Commands
    fileprivate func discoverService(with command: BleCommand) {
        var serviceUuids = command.parameters as? [CBUUID]
        let discoverAll = serviceUuids == nil
        
        // Remove services already discovered from the query
        if let services = peripheral.services, let serviceUuidsToDiscover = serviceUuids {
            for (i, serviceUuid) in serviceUuidsToDiscover.enumerated().reversed() {
                if !services.contains(where: {$0.uuid == serviceUuid}) {
                    serviceUuids!.remove(at: i)
                }
            }
        }
        
        // Discover remaining uuids
        if discoverAll || serviceUuids != nil {
            peripheral.discoverServices(serviceUuids)
        }
        else {
            // Everthing was already discovered
            finishedExecutingCommand(error: nil)
        }
    }
    
    fileprivate func discoverCharacteristic(with command: BleCommand) {
        var characteristicUuids = command.parameters![0] as? [CBUUID]
        let discoverAll = characteristicUuids == nil
        let service = command.parameters![1] as! CBService
        
        // Remove services already discovered from the query
        if let characteristics = service.characteristics, let characteristicUuidsToDiscover = characteristicUuids {
            for (i, characteristicUuid) in characteristicUuidsToDiscover.enumerated().reversed() {
                if !characteristics.contains(where: {$0.uuid == characteristicUuid}) {
                    characteristicUuids!.remove(at: i)
                }
            }
        }
        
        // Discover remaining uuids
        if discoverAll || characteristicUuids != nil {
            peripheral.discoverCharacteristics(characteristicUuids, for: service)
        }
        else {
            // Everthing was already discovered
            finishedExecutingCommand(error: nil)
        }
    }
    
    fileprivate func setNotify(with command: BleCommand) {
        let characteristic = command.parameters![0] as! CBCharacteristic
        let enabled = command.parameters![1] as! Bool
        let handler = command.parameters![2] as? ((Error?) -> Void)
        let identifier = handlerIdentifier(from: characteristic)
        if enabled {
            notifyHandlers[identifier] = handler
        }
        else {
            notifyHandlers.removeValue(forKey: identifier)
        }
        peripheral.setNotifyValue(enabled, for: characteristic)
    }
    
    fileprivate func read(with command: BleCommand) {
        let characteristic = command.parameters!.first as! CBCharacteristic
        peripheral.readValue(for: characteristic)
    }

    
    fileprivate func write(with command: BleCommand) {
        let characteristic = command.parameters![0] as! CBCharacteristic
        let writeType = command.parameters![1] as! CBCharacteristicWriteType
        let data = command.parameters![2] as! Data
        
        peripheral.writeValue(data, for: characteristic, type: writeType)
        
        /*  According to Apple docs, .withouthResponse should not call to 'didUpdateValueFor characteristic', but it does
        if writeType == .withoutResponse {
            finishedExecuting(command: command, resultError: nil)
        }*/
    }

}

extension BlePeripheral: CBPeripheralDelegate {
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
         DLog("peripheralDidUpdateName: \(name)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("didModifyServices")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        /*
        guard let command = commandQueue.first(where: {$0.type == .discoverService}) else {
            DLog("discoverService without matching command")
            return
        }
 */
        
        finishedExecutingCommand(error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        /*
        struct Holder {
            // Used to keep track of the last command completion handler. This funcion can be called an undeterminate number of times when asked to discover all the characteristics, so we don't know when it is going to stop
            static var lastCompletionHandler: ((Error?) -> Void)?
        }
 */
            /*
        guard let command = commandQueue.first(where: {$0.type == .discoverCharacteristic && service.uuid == ($0.parameters?.last as? CBService)?.uuid }) else {
            DLog("discoverCharacteristic without matching command")
  //          Holder.lastCompletionHandler?(error)
            return
        }
        */
  //      Holder.lastCompletionHandler = command.completion
        finishedExecutingCommand(error: error)
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        /*
        guard let command = commandQueue.first(where: {$0.type == .setNotify}) else {
            DLog("setNotify without matching command")
            return
        }*/
        
        finishedExecutingCommand(error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let identifier = handlerIdentifier(from: characteristic)
        if let handler = notifyHandlers[identifier] {
            handler(error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        /*
        guard let command = commandQueue.first(where: {$0.type == .write /*&& ($0.parameters![2] as! CBCharacteristicWriteType) == .withResponse*/ }) else {
            DLog("write without matching command")
            return
        }*/
        
        finishedExecutingCommand(error: error)
    }
}
