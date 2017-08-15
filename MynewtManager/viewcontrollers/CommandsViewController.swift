//
//  CommandsViewController.swift
//  MynewtManager
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
    
    override func newtDidBecomeReady() {
        super.newtDidBecomeReady()
        
        updateUI()
    }

    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
    
    fileprivate func sendRequest(for command: NewtHandler.Command) {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: command) { [weak self] (result, error) in
                guard let context = self else {
                    return
                }
                
            DispatchQueue.main.async {
                guard error == nil else {
                    DLog("Error: \(error!)")
                    
                    NewtHandler.newtShowErrorAlert(from: context, title: "Error", error: error!)
                    return
                }
                
//                context.updateUI()
            }
        }
    }
}

extension CommandsViewController: UITableViewDataSource {
    enum Commands: Int {
        case reset = 0
        case imageList
        case echo
        
        var name: String {
            switch self {
            case .reset: return "Reset"
            case .imageList: return "Image List"
            case .echo: return  "Echo"
            }
        }
    }
    
    private static let kNumCommands = 3
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (blePeripheral?.isNewtReady ?? false) ? CommandsViewController.kNumCommands:0
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
        guard let command = Commands(rawValue: indexPath.row) else { return }
        cell.textLabel!.text = command.name
        cell.accessoryType = .disclosureIndicator
    }
}

extension CommandsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        guard let command = Commands(rawValue: indexPath.row) else { return }
        
        switch command {
        case .reset:
            sendRequest(for: .reset)
            
        case .imageList:
            sendRequest(for: .imageList)
            
        case .echo:
            let alert = UIAlertController(title: "Enter Echo message", message: "Message", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.placeholder = "Hello"
            }
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [unowned self] (_) in
                let textField = alert.textFields![0]
                if let message = textField.text {
                    self.sendRequest(for: .echo(message: message))
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
