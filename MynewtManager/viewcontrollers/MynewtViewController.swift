//
//  MynewtViewController.swift
//  MynewtManager
//
//  Created by Antonio García on 15/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class MynewtViewController: UIViewController {

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
    
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        // If the segue is for a MynewtViewController, propagate the blePeripheral automatically
        if let newtViewController = segue.destination as? MynewtViewController {
            newtViewController.blePeripheral = blePeripheral
        }

    }
    
    
    func newtDidBecomeReady() {
        // To be overrided by subclasses
    }

}
