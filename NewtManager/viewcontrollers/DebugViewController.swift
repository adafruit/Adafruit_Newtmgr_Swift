//
//  DebugViewController.swift
//  NewtManager
//
//  Created by Antonio García on 18/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class DebugViewController: NewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    

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
        
        updateUI()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    
    override func newtBecomeReady() {
        super.newtBecomeReady()
        
        updateUI()
    }

    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
    
    
    fileprivate func sendRequest(for command: BlePeripheral.NmgrCommand) {
        guard let peripheral = blePeripheral, peripheral.isNewtManagerReady else {
            return
        }
        
        peripheral.newtRequest(with: command) { [weak self] (result, error) in
            DispatchQueue.main.async {
                guard let context = self else {
                    return
                }
                
                guard error != nil else {
                    DLog("Error: \(error!)")
                    
                    
                    BlePeripheral.newtShowErrorAlert(from: context, title: "Error", error: error!)
                    return
                }
                
//                context.updateUI()
            }
        }
    }
}

extension DebugViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let kNumCommands = 1
        return (blePeripheral?.isNewtManagerReady ?? false) ? kNumCommands:0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "CommandCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        var title: String?
        switch indexPath.row {
        case 0:
            title = "Reset"
        default:
            title = nil
        }
        
        cell.textLabel!.text = title
        cell.accessoryType = .disclosureIndicator

    }
}

extension DebugViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        
        switch indexPath.row {
        case 0:
            sendRequest(for: .reset)
        default:
            break
        }
        
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

