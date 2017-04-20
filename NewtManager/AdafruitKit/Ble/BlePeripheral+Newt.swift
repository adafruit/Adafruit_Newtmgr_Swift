//
//  NewtManager.swift
//  NewtManager
//
//  Created by Antonio García on 14/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth


extension BlePeripheral {
    // Costants
    static let kNewtServiceUUID = CBUUID(string: "8D53DC1D-1DB7-4CD3-868B-8A527460AA84")
    private static let kNewtCharacteristicUUID = CBUUID(string:"DA2E7828-FBCE-4E01-AE9E-261174997C48")
    
    // MARK: - Custom properties
    private struct CustomPropertiesKeys {
        static var newtCharacteristic: CBCharacteristic?
        static var newtCharacteristicWriteType: CBCharacteristicWriteType?
        static var newtHandler: NewtHandler?
    }

    fileprivate var newtCharacteristic: CBCharacteristic? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristic) as! CBCharacteristic?
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristic, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    fileprivate var newtCharacteristicWriteType: CBCharacteristicWriteType? {
        get {
            return objc_getAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristicWriteType) as! CBCharacteristicWriteType?
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.newtCharacteristicWriteType, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    fileprivate var newtHandler: NewtHandler {
        get {
            var handler = objc_getAssociatedObject(self, &CustomPropertiesKeys.newtHandler) as! NewtHandler?
            if handler == nil {
                handler = NewtHandler()
                self.newtHandler = handler!
            }
            return handler!
        }
        set {
            objc_setAssociatedObject(self, &CustomPropertiesKeys.newtHandler, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    enum NewtError: Error {
        case invalidCharacteristic
        case enableNotifyFailed
        
        var description: String {
            switch self {
            case .invalidCharacteristic: return "Newt characteristic is invalid"
            case .enableNotifyFailed: return "Cannot enable notification on Newt characteristic"
            }
        }
    }
    
    // MARK: - Initialization
    func newtInit(completion: ((Error?) -> Void)?) {
        newtHandler.delegate = self
        newtHandler.start()
        
        // Get newt communications characteristic
        characteristic(uuid: BlePeripheral.kNewtCharacteristicUUID, serviceUuid: BlePeripheral.kNewtServiceUUID) { [unowned self] (characteristic, error) in
            if let characteristic = characteristic, error == nil {
                // Get characteristic info
                self.newtCharacteristic = characteristic
                self.newtCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse:.withResponse
                
                // Enable notifications
                self.setNotify(for: characteristic, enabled: true, handler: { [unowned self] (error) in
                    self.newtHandler.newtReceivedData(data: characteristic.value, error: error)
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
            newtHandler.stop()
        }
        
        if !wasDisconnected, let characteristic = newtCharacteristic {
            // Disable notify
            setNotify(for: characteristic, enabled: false)
        }
    }
    
    // MARK: - Commands 
    func newtSendRequest(with command: NewtHandler.Command, progress: NewtHandler.RequestProgressHandler? = nil, completion: NewtHandler.RequestCompletionHandler?) {
            newtHandler.sendRequest(with: command, progress: progress, completion: completion)
    }
   
}

extension BlePeripheral: NewtStateDelegate {
    func onNewtWrite(data: Data, completion: NewtHandler.RequestCompletionHandler?) {
        guard let newtCharacteristic = newtCharacteristic, let newtCharacteristicWriteType = newtCharacteristicWriteType else {
            DLog("Command Error: Peripheral not configured. Use setup()")
            completion?(nil, NewtError.invalidCharacteristic)
            return
        }

        write(data: data, for: newtCharacteristic, type: newtCharacteristicWriteType) { error in
            if error != nil {
                DLog("Error: \(error!)")
            }
            
            completion?(nil, error)
        }
    }
}

