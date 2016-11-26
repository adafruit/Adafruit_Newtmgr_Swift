//
//  NewtViewController.swift
//  NewtManager
//
//  Created by Antonio García on 15/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class NewtViewController: UIViewController {

    weak var blePeripheral: BlePeripheral?
    
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
        
        // Setup navigation item
        if let parentNavigationItem = parent?.navigationItem {
            // Setup navigation item title and buttons
            parentNavigationItem.title = navigationItem.title
            parentNavigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems
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
    
    func newtDidBecomeReady() {
        // To be overrided by subclasses
    }

}
