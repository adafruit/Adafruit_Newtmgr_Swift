//
//  StatsViewController.swift
//  NewtManager
//
//  Created by Antonio García on 03/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class StatsViewController: NewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private let refreshControl = UIRefreshControl()

    // Data
    fileprivate var stats: [String]?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if stats == nil {
            refreshStats()
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let statsDetailViewController = segue.destination as? StatsDetailViewController, let stats = stats, let selectedIndex = baseTableView.indexPathForSelectedRow?.row {
            statsDetailViewController.statId = stats[selectedIndex]
        }
    }


    
    // MARK: - Newt
    override func newtDidBecomeReady() {
        super.newtDidBecomeReady()
        
        // Refresh if no data was previously loaded and view is visible
        if stats == nil && isViewLoaded && view.window != nil {
            refreshStats()
        }
    }
    
    private func refreshStats() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: .stats) { [weak self] (stats, error) in
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
            
            if let stats = stats as? [String] {
                DLog("Stats: \(stats.joined(separator: ", "))")
                context.setStats(stats)
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
    }
    
    private func setStats(_ stats: [String]) {
        let sortedStats = stats.sorted(by: <)
        self.stats = sortedStats
    }
    
    // MARK: - UI
    func onTableRefresh(_ sender: AnyObject) {
        refreshStats()
        refreshControl.endRefreshing()
    }
    
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension StatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stats?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "StatCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let stat = stats?[indexPath.row] else {
            return
        }
        
        cell.textLabel?.text = stat
        cell.accessoryType = .disclosureIndicator
    }
}

// MARK: - UITableViewDelegate
extension StatsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        performSegue(withIdentifier: "detailsSegue", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


