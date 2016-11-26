//
//  TaksViewController.swift
//  NewtManager
//
//  Created by Antonio García on 14/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class TaksViewController: NewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    
    // 
    fileprivate var tasks: [String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if tasks == nil {
            refreshTaks()
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
    
    override func newtBecomeReady() {
        super.newtBecomeReady()

        // Refresh if no data was previously loaded and view is visible
        if tasks == nil && isViewLoaded && view.window != nil {
            refreshTaks()
        }
    }
    
    private func refreshTaks() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtRequest(with: .taskStats) { [weak self] (imageVersionStrings, error) in            
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error TasksStats: \(error!)")
                context.tasks = nil
                
                DispatchQueue.main.async {
                    showErrorAlert(from: context, title: "Error", message: "Error retrieving tasks stats")
                }
            }

            if let imageVersionStrings = imageVersionStrings as? [String] {
                DLog("TasksStats: \(imageVersionStrings.joined(separator: ", "))")
                context.tasks = imageVersionStrings
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
    }
    
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
}

extension TaksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "TaskCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let taskName = tasks![indexPath.row]
        cell.accessoryType = .disclosureIndicator
        cell.textLabel!.text = taskName
    }
}

extension TaksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
}

