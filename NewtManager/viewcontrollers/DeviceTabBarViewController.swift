//
//  DeviceTabBarViewController.swift
//  NewtManager
//
//  Created by Antonio García on 15/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class DeviceTabBarViewController: UITabBarController {
    
    // Parameters
    weak var blePeripheral: BlePeripheral? {
        // Send to tabs view controllers
        didSet {
            if let viewControllers = viewControllers {
                for viewController in viewControllers {
                    if let newtViewController = viewController as? NewtViewController {
                        newtViewController.blePeripheral = blePeripheral
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup
        guard let peripheral = blePeripheral else {
            DLog("Error: Peripheral is undefined")
            return
        }
        
        peripheral.newtInit() { [weak self] error in
            guard let context = self else {
                return
            }
            
            guard error == nil else {
                DLog("Newt setup error: \(error!)")
                
                DispatchQueue.main.async {
                    showErrorAlert(from: context, title: "Error", message: "Error initializing Newt service") { [unowned context] _ in
                        // Go back to scanning controller
                        _ = context.navigationController?.popToRootViewController(animated: true)
                    }
                }
                
                BleManager.sharedInstance.disconnect(from: peripheral)
                return
            }
            
            if let context = self, let newtController = context.selectedViewController as? NewtViewController {
                newtController.newtDidBecomeReady()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
        
    deinit {
        if let peripheral = blePeripheral {
            BleManager.sharedInstance.disconnect(from: peripheral)
        }
        else {
            DLog("Cannot disconnect because peripheral is undefined")
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
