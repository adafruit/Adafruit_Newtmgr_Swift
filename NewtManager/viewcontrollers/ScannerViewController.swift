//
//  ScannerViewController.swift
//  NewtManager
//
//  Created by Antonio García on 13/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ScannerViewController: UIViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private let refreshControl = UIRefreshControl()

    // Data
    fileprivate var peripherals = [BlePeripheral]()
    fileprivate var selectedPeripheral: BlePeripheral?
    fileprivate var expectingDisconnetionFromPeripheralUuid: UUID?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)

        // Ble Notifications
        registerNotifications(enabled: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Start scannning
        BleManager.sharedInstance.startScan()
//        BleManager.sharedInstance.startScan(withServices: [BlePeripheral.kNewtServiceUUID])
        
        // Update UI
        updateScannedPeripherals()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop scanning
        BleManager.sharedInstance.stopScan()
        
        // Clear peripherals
        peripherals = [BlePeripheral]()
    }
    
    deinit {
        // Ble Notifications
        registerNotifications(enabled: false)
    }
   
    // MARK: - BLE Notifications
    
    private func registerNotifications(enabled: Bool) {
        if enabled {
            NotificationCenter.default.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: OperationQueue.main, using: didDiscoverPeripheral)
            NotificationCenter.default.addObserver(forName: .willConnectToPeripheral, object: nil, queue: OperationQueue.main, using: willConnectToPeripheral)
            NotificationCenter.default.addObserver(forName: .didConnectToPeripheral, object: nil, queue: OperationQueue.main, using: didConnectToPeripheral)
            NotificationCenter.default.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: willDisconnectFromPeripheral)
            NotificationCenter.default.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: OperationQueue.main, using: didDisconnectFromPeripheral)
        }
        else {
            NotificationCenter.default.removeObserver(self, name: .didDiscoverPeripheral, object: nil)
            NotificationCenter.default.removeObserver(self, name: .willConnectToPeripheral, object: nil)
            NotificationCenter.default.removeObserver(self, name: .didConnectToPeripheral, object: nil)
            NotificationCenter.default.removeObserver(self, name: .willDisconnectFromPeripheral, object: nil)
            NotificationCenter.default.removeObserver(self, name: .didDisconnectFromPeripheral, object: nil)
        }
    }
    
    private func didDiscoverPeripheral(notification: Notification) {
        // Update current scanning state
        updateScannedPeripherals()
    }
    
    
    private func willConnectToPeripheral(notification: Notification) {
        
        guard let peripheral = BleManager.sharedInstance.peripheral(from: notification) else {
            return
        }
        
        DLog("Connecting...");
        let alertController = UIAlertController(title: nil, message: "Connecting...", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) -> Void in
            BleManager.sharedInstance.disconnect(from: peripheral)
        }))
        present(alertController, animated: true, completion:nil)
    }
    
    
    private func didConnectToPeripheral(notification: Notification) {
        // Reset values on connection
        expectingDisconnetionFromPeripheralUuid = nil
        
        // Show peripheral details
        if presentedViewController != nil {   // Dismiss current dialog if present
            dismiss(animated: true, completion: { [weak self] () -> Void in
                self?.showPeripheralDetails()
            })
        }
        else {
            showPeripheralDetails()
        }
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
        
        guard let selectedPeripheral = selectedPeripheral, peripheral.identifier == selectedPeripheral.identifier else {
            return
        }
        
        // Clear selected peripheral
        self.selectedPeripheral = nil
        
        // Clear newt status if needed
        peripheral.newtDeInit()
        
        // If not an expected disconnection then show an alert to the user
        if peripheral.identifier == expectingDisconnetionFromPeripheralUuid {
            expectingDisconnetionFromPeripheralUuid = nil
        }
        else {
            // Show alert
            if presentedViewController != nil {
                dismiss(animated: true, completion: { () -> Void in
                    self.showPeripheralDisconnectedDialog()
                })
            }
            else {
                showPeripheralDisconnectedDialog()
            }
        }
    }
    
    // MARK: - Navigation
    private func showPeripheralDetails() {
        performSegue(withIdentifier: "showDetailSegue", sender: self)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return selectedPeripheral != nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? DeviceTabBarViewController {
            viewController.blePeripheral = selectedPeripheral
        }
    }
    
    // MARK: - UI
    private func showPeripheralDisconnectedDialog() {
        showErrorAlert(from: self, title: nil, message: "Peripheral Disconnected") { [unowned self] _ in
            _ = self.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    private func updateScannedPeripherals() {
    
        // Update current peripheral list
        let kUnnamedSortingString = "~~~"       // Unnamed devices go to the bottom
        peripherals = BleManager.sharedInstance.peripherals().sorted(by: {$0.name ?? kUnnamedSortingString < $1.name ?? kUnnamedSortingString})
        
        // Reload table
        baseTableView.reloadData()
        
        // Select the previously selected row
        if let selectedPeripheral = selectedPeripheral, let selectedRow = peripherals.index(of: selectedPeripheral) {
            baseTableView.selectRow(at: IndexPath(row: selectedRow, section: 0), animated: false, scrollPosition: .none)
        }
    }
    
    func onTableRefresh(_ sender: AnyObject) {
        BleManager.sharedInstance.refreshPeripherals()
        refreshControl.endRefreshing()
    }
}

extension ScannerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "PeripheralCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        cell.textLabel!.text = peripheral.name ?? "<Unknown>"
    }
}

extension ScannerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let peripheral = peripherals[indexPath.row]
        selectedPeripheral = peripheral
        BleManager.sharedInstance.connect(to: peripheral)
    }
}

