//
//  CommandsViewController.swift
//  NewtManager
//
//  Created by Antonio García on 18/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class CommandsViewController: NewtViewController {

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
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtRequest(with: command) { [weak self] (result, error) in
            DispatchQueue.main.async {
                guard let context = self else {
                    return
                }
                
                guard error == nil else {
                    DLog("Error: \(error!)")
                    
                    
                    BlePeripheral.newtShowErrorAlert(from: context, title: "Error", error: error!)
                    return
                }
                
//                context.updateUI()
            }
        }
    }
}

extension CommandsViewController: UITableViewDataSource {
    private static let kCommandNames = ["Reset", "Boot version"]
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (blePeripheral?.isNewtReady ?? false) ? CommandsViewController.kCommandNames.count:0
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
        cell.textLabel!.text = CommandsViewController.kCommandNames[indexPath.row]
        cell.accessoryType = .disclosureIndicator

    }
}

extension CommandsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch indexPath.row {
        case 0:
            sendRequest(for: .reset)
            
        case 1:
            let alert = UIAlertController(title: "Enter version to boot", message: "Version", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.placeholder = "0.0.0"
            }
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [unowned self] (_) in
                let textField = alert.textFields![0]
                if let version = textField.text {
                    self.sendRequest(for: .bootVersion(version: version))
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
            

        default:
            break
        }
        
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

