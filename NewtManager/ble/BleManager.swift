//
//  NewtManager.swift
//  NewtManager
//
//  Created by Antonio García on 13/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class BleManager: NSObject {
    // Configuration
    private static let kStopScanningWhenConnectingToPeripheral = false
    private static let kAlwaysAllowDuplicateKeys = false

    // Singleton
    static let sharedInstance = BleManager()
    
    // Ble
    var centralManager: CBCentralManager?
    
    // Scanning
    fileprivate var isScanning = false
    fileprivate var isScanningWaitingToStart = false
    fileprivate var scanningWaitingToStartServices: [CBUUID]?
    fileprivate var peripheralsFound = [UUID: BlePeripheral]()

    // Notifications
    enum NotificationUserInfoKey: String {
        case uuid = "uuid"
    }
    
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .background), options: [:])
    }
    
    // MARK: - Scan
    func startScan(withServices services: [CBUUID]? = nil) {
        guard let centralManager = centralManager, centralManager.state != .poweredOff && centralManager.state != .unauthorized && centralManager.state != .unsupported else {
            DLog("startScan failed because central manager is not ready")
            return
        }
        
        isScanningWaitingToStart = true
        scanningWaitingToStartServices = services
        
        guard centralManager.state == .poweredOn else {
            return
        }
        
        isScanning = true
        NotificationCenter.default.post(name: .didStartScanning, object: nil)
        centralManager.scanForPeripherals(withServices: services, options: BleManager.kAlwaysAllowDuplicateKeys ? [CBCentralManagerScanOptionAllowDuplicatesKey: true] : nil)
    }
    
    func stopScan() {
        centralManager?.stopScan()
        isScanning = false
        isScanningWaitingToStart = false
        scanningWaitingToStartServices = nil
        NotificationCenter.default.post(name: .didStopScanning, object: nil)
    }
    
    func peripherals() -> [BlePeripheral] {
        return Array(peripheralsFound.values)
    }
    
    // MARK: - Connection Management
    func connect(to peripheral: BlePeripheral) {
        
        // Stop scanning when connecting to a peripheral 
        if BleManager.kStopScanningWhenConnectingToPeripheral {
            stopScan()
        }
        
        // Connect
        NotificationCenter.default.post(name: .willConnectToPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
        
        DLog("connect")
        centralManager?.connect(peripheral.peripheral, options: nil)
    }
    
    func disconnect(from peripheral: BlePeripheral) {
        
        DLog("disconnect")
        NotificationCenter.default.post(name: .willDisconnectFromPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue: peripheral.identifier])
        centralManager?.cancelPeripheralConnection(peripheral.peripheral)
    }
    
    // MARK:- Notifications
    func peripheral(from notification: Notification) -> BlePeripheral? {
        
        guard let uuid = notification.userInfo?[NotificationUserInfoKey.uuid.rawValue] as? UUID else {
            return nil
        }
        
        return peripheral(with: uuid)
    }
    
    func peripheral(with uuid: UUID) -> BlePeripheral? {
        return peripheralsFound[uuid]
    }

}

// MARK: - CBCentralManagerDelegate
extension BleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if (central.state == .poweredOn) {
            if (isScanningWaitingToStart) {
                startScan(withServices: scanningWaitingToStartServices)        // Continue scanning now that bluetooth is back
            }
        }
        else {
            isScanning = false
        }
        
        NotificationCenter.default.post(name: .didUpdateBleState, object: nil)
    }
    
    /*
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        
    }*/
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        if let existingPeripheral = peripheralsFound[peripheral.identifier] {
            existingPeripheral.rssi = RSSI.intValue
            existingPeripheral.lastSeenTime = CFAbsoluteTimeGetCurrent()
            for (key, value) in advertisementData {
                existingPeripheral.advertisementData.updateValue(value, forKey: key);
            }
            peripheralsFound[peripheral.identifier] = existingPeripheral
            
        }
        else {      // New peripheral found
            let peripheral = BlePeripheral(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI.intValue)
            peripheralsFound[peripheral.identifier] = peripheral
        }
        
        NotificationCenter.default.post(name: .didDiscoverPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue : peripheral.identifier])
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DLog("didConnect")
        
        NotificationCenter.default.post(name: .didConnectToPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue : peripheral.identifier])
        
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DLog("didFailToConnect")

        NotificationCenter.default.post(name: .didDisconnectFromPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue : peripheral.identifier])

    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DLog("didDisconnectPeripheral")

        NotificationCenter.default.post(name: .didDisconnectFromPeripheral, object: nil, userInfo: [NotificationUserInfoKey.uuid.rawValue : peripheral.identifier])

    }
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kNotificationsPrefix = Bundle.main.bundleIdentifier!
    static let didUpdateBleState = Notification.Name(kNotificationsPrefix+".didUpdateBleState")
    static let didStartScanning = Notification.Name(kNotificationsPrefix+".didStartScanning")
    static let didStopScanning = Notification.Name(kNotificationsPrefix+".didStopScanning")
    static let didDiscoverPeripheral = Notification.Name(kNotificationsPrefix+".didDiscoverPeripheral")
    static let didUnDiscoverPeripheral = Notification.Name(kNotificationsPrefix+".didUnDiscoverPeripheral")
    static let willConnectToPeripheral = Notification.Name(kNotificationsPrefix+".willConnectToPeripheral")
    static let didConnectToPeripheral = Notification.Name(kNotificationsPrefix+".didConnectToPeripheral")
    static let willDisconnectFromPeripheral = Notification.Name(kNotificationsPrefix+".willDisconnectFromPeripheral")
    static let didDisconnectFromPeripheral = Notification.Name(kNotificationsPrefix+".didDisconnectFromPeripheral")
}
