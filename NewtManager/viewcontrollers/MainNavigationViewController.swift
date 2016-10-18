//
//  MainNavigationViewController.swift
//  NewtManager
//
//  Created by Antonio García on 14/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class MainNavigationViewController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(forName: .didUpdateBleState, object: nil, queue: OperationQueue.main, using: didUpdateBleState)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: .didUpdateBleState, object: nil)
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    
    // MARK: - Ble Notifications

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
            showErrorAlert(from: self, title: "Error", message: errorMessage)
        }
    }
}


