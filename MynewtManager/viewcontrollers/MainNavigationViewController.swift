//
//  MainNavigationViewController.swift
//  MynewtManager
//
//  Created by Antonio García on 14/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class MainNavigationViewController: UINavigationController {
    // Data
    fileprivate var expectingDisconnetionFromPeripheralUuid: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()

        registerNotifications(enabled: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    deinit {
        registerNotifications(enabled: false)
    }
    
    // MARK: - Ble Notifications
    
    private func registerNotifications(enabled: Bool) {
        struct Holder {
            static var didUpdateBleStateObserver: NSObjectProtocol?
            static var didConnectToPeripheralObserver: NSObjectProtocol?
            static var willDisconnectFromPeripheralObserver: NSObjectProtocol?
            static var didDisconnectFromPeripheralObserver: NSObjectProtocol?
        }
        
        if enabled {
            Holder.didUpdateBleStateObserver = NotificationCenter.default.addObserver(forName: .didUpdateBleState, object: nil, queue: OperationQueue.main, using: didUpdateBleState)
            Holder.didConnectToPeripheralObserver = NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: OperationQueue.main, using: didConnectToPeripheral)
            Holder.willDisconnectFromPeripheralObserver = NotificationCenter.default.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: willDisconnectFromPeripheral)
            Holder.didDisconnectFromPeripheralObserver = NotificationCenter.default.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: didDisconnectFromPeripheral)
        }
        else {
            if let didUpdateBleStateObserver = Holder.didUpdateBleStateObserver {NotificationCenter.default.removeObserver(didUpdateBleStateObserver)}
            if let didConnectToPeripheralObserver = Holder.didConnectToPeripheralObserver {NotificationCenter.default.removeObserver(didConnectToPeripheralObserver)}
            if let willDisconnectFromPeripheralObserver = Holder.willDisconnectFromPeripheralObserver {NotificationCenter.default.removeObserver(willDisconnectFromPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = Holder.didDisconnectFromPeripheralObserver {NotificationCenter.default.removeObserver(didDisconnectFromPeripheralObserver)}
        }
    }
    
    private func didUpdateBleState(notification: Notification) {
        guard let state = BleManager.sharedInstance.centralManager?.state else {
            return
        }
        
        // Check if there is any error
        var errorMessage: String?
        switch state {
        case .unsupported:
            errorMessage = "This device doesn't support Bluetooth Low Energy"
        case .unauthorized:
            errorMessage = "This app is not authorized to use the Bluetooth Low Energy"
        case.poweredOff:
            errorMessage = "Bluetooth is currently powered off"
            
        default:
            errorMessage = nil
        }
        
        // Show alert if error found
        if let errorMessage = errorMessage {
            DLog("ble status change alert: \(errorMessage)")
            DispatchQueue.main.async { [unowned self] in
                showErrorAlert(from: self, title: "Error", message: errorMessage)
            }
        }
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        // Reset values on connection
        expectingDisconnetionFromPeripheralUuid = nil
    }
    
    
    private func willDisconnectFromPeripheral(notification: Notification) {
        guard let peripheral = BleManager.sharedInstance.peripheral(from: notification) else {
            return
        }
        
        expectingDisconnetionFromPeripheralUuid =  peripheral.identifier
    }
    
    private func didDisconnectFromPeripheral(notification: Notification) {
        
        guard let peripheral = BleManager.sharedInstance.peripheral(from: notification) else {
            return
        }
        
        // Clear newt status if needed
        peripheral.newtDeInit(wasDisconnected: true)
        
        // If not an expected disconnection then show an alert to the user or prepare for reconnection
        if peripheral.identifier == self.expectingDisconnetionFromPeripheralUuid {
            // Expected disonnection
            self.expectingDisconnetionFromPeripheralUuid = nil
        }
        else {
            // Unexpected disconnection
            DispatchQueue.main.async { [unowned self] in
                // Show alert
                if self.presentedViewController != nil {
                    self.dismiss(animated: true, completion: { [unowned self] () -> Void in
                        self.showPeripheralDisconnectedDialog()
                    })
                }
                else {
                    self.showPeripheralDisconnectedDialog()
                }
            }
        }
    }
    
    private func showPeripheralDisconnectedDialog() {
        showErrorAlert(from: self, title: nil, message: "Peripheral Disconnected") { [unowned self] _ in
            _ = self.popToRootViewController(animated: true)
        }
    }
}


