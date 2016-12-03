//
//  StatsDetailViewController.swift
//  NewtManager
//
//  Created by Antonio García on 03/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class StatsDetailViewController: NewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private let refreshControl = UIRefreshControl()
    
    // Data
    fileprivate var stats: [NewtManager.StatDetails]?
    private let numberFormatter = NumberFormatter()

    var statId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        numberFormatter.numberStyle = .decimal

        
        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if stats == nil, let statId = statId {
            refresh(statId: statId)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    
    // MARK: - Newt
    override func newtDidBecomeReady() {
        super.newtDidBecomeReady()
        
        // Refresh if no data was previously loaded and view is visible
        if stats == nil && isViewLoaded && view.window != nil, let statId = statId  {
            refresh(statId: statId)
        }
    }
    
    private func refresh(statId: String) {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: .stat(statId: statId)) { [weak self] (stats, error) in
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error Stats: \(error!)")
                context.stats = nil
                
                DispatchQueue.main.async {
                    showErrorAlert(from: context, title: "Error", message: "Error retrieving Stats")
                }
            }
            
            if let stats = stats as? [NewtManager.StatDetails] {
                //DLog("Stats: \(stats.joined(separator: ", "))")
                context.setStats(stats)
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
    }
    
    private func setStats(_ stats: [NewtManager.StatDetails]) {
        let sortedStats = stats.sorted(by: {$0.name < $1.name})
        self.stats = sortedStats
    }
    
    fileprivate func format(value: UInt) -> String {
        let number =  NSNumber(value: value)
        return (numberFormatter.string(from: number) ?? "" )
    }
    
    // MARK: - UI
    func onTableRefresh(_ sender: AnyObject) {
        
        if let statId = statId {
            refresh(statId: statId)
        }
        refreshControl.endRefreshing()
    }
    
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
    
   
}

// MARK: - UITableViewDataSource
extension StatsDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stats?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "StatCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let stat = stats?[indexPath.row] else {
            return
        }
        
        cell.textLabel?.text = stat.name
        cell.detailTextLabel?.text = format(value: stat.value)
        cell.accessoryType = .none
    }
}

// MARK: - UITableViewDelegate
extension StatsDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
