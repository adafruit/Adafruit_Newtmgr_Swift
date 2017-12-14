//
//  StatsDetailViewController.swift
//  MynewtManager
//
//  Created by Antonio García on 03/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class StatsDetailViewController: MynewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private let refreshControl = UIRefreshControl()
    @IBOutlet weak var playButton: UIBarButtonItem!
 
    // Data
    fileprivate var stats: [NewtHandler.StatDetails]?
    private let numberFormatter = NumberFormatter()
    fileprivate var autoRefresh: AutoRefresh!

    var statId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        numberFormatter.numberStyle = .decimal

        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)
        
        // AutoRefresh
        autoRefresh = AutoRefresh(onFired: refreshStat)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if stats == nil {
            refreshStat()
        }
        
        autoRefresh.isPaused = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        autoRefresh.isPaused = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        autoRefresh.stop()
    }

    // MARK: - Newt
    override func newtDidBecomeReady() {
        super.newtDidBecomeReady()
        
        // Refresh if no data was previously loaded and view is visible
        if stats == nil && isViewLoaded && view.window != nil  {
            refreshStat()
        }
    }

    
    private func refreshStat() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady, let statId = statId else {
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
            
            if let stats = stats as? [NewtHandler.StatDetails] {
                //DLog("Stats: \(stats.joined(separator: ", "))")
                context.setStats(stats)
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
    }
    
    private func setStats(_ stats: [NewtHandler.StatDetails]) {
        let sortedStats = stats.sorted(by: {$0.name < $1.name})
        self.stats = sortedStats
    }
    
    fileprivate func format(value: UInt) -> String {
        let number =  NSNumber(value: value)
        return (numberFormatter.string(from: number) ?? "" )
    }
    
    // MARK: - UI
    @objc func onTableRefresh(_ sender: AnyObject) {
        
        refreshStat()
        refreshControl.endRefreshing()
    }
    
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
    
    
    // MARK: - Auto Refresh
    @IBAction func onClickPlay(_ sender: Any) {
        
        if !autoRefresh.isStarted {
            autoRefresh.start()
            playButton.image = UIImage(named: "ic_pause_circle_outline")
            //taskViewController?.setPlaying(true)
        }
        else {
            autoRefresh.stop()
            playButton.image = UIImage(named: "ic_play_circle_outline")
            // taskViewController?.setPlaying(false)
        }
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
