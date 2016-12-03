//
//  TaksViewController.swift
//  NewtManager
//
//  Created by Antonio García on 14/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import MSWeakTimer

class TaksViewController: NewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private let refreshControl = UIRefreshControl()
    @IBOutlet weak var playButton: UIBarButtonItem!
 
    // Data
    fileprivate var taskStats: [NewtTaskStats]?
    fileprivate var refreshTimer: MSWeakTimer?
    fileprivate var isRefreshTimerPaused = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if taskStats == nil {
            refreshTasks()
        }
        
        isRefreshTimerPaused = false
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        isRefreshTimerPaused = true
    }
    
    deinit {
        cancelRefreshTimer()
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let taskViewController = segue.destination as? TaskViewController, let taskStats = taskStats, let selectedTaskIndex = baseTableView.indexPathForSelectedRow?.row {
            taskViewController.task = taskStats[selectedTaskIndex]
        }
    }

    // MARK: - Newt
    override func newtDidBecomeReady() {
        super.newtDidBecomeReady()
        
        // Refresh if no data was previously loaded and view is visible
        if taskStats == nil && isViewLoaded && view.window != nil {
            refreshTasks()
        }
    }
    
    private func refreshTasks() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: .taskStats) { [weak self] (taskStats, error) in
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error TasksStats: \(error!)")
                context.taskStats = nil
                
                DispatchQueue.main.async {
                    showErrorAlert(from: context, title: "Error", message: "Error retrieving tasks stats")
                }
            }
            
            if let taskStats = taskStats as? [NewtTaskStats] {
                context.setTaskStats(taskStats)
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
        
    }
    
    private func setTaskStats(_ taskStats: [NewtTaskStats]) {
        let sortedTasks = taskStats.sorted(by: {$0.priority < $1.priority})
        self.taskStats = sortedTasks
    }

    
    // MARK: - UI
    func onTableRefresh(_ sender: AnyObject) {
        refreshTasks()
        refreshControl.endRefreshing()
    }
    
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
    
    // MARK: - Actions
    @IBAction func onClickPlay(_ sender: Any) {
     
        if refreshTimer == nil {
            let kTimeInterval = 0.5
            isRefreshTimerPaused = false
            refreshTimer = MSWeakTimer.scheduledTimer(withTimeInterval: kTimeInterval, target: self, selector: #selector(refreshFired), userInfo: nil, repeats: true, dispatchQueue: .main)
            
            playButton.image = UIImage(named: "ic_pause_circle_outline")
        }
        else {
            playButton.image = UIImage(named: "ic_play_circle_outline")

           cancelRefreshTimer()
        }
    }
    
    private func cancelRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @objc func refreshFired(timer: MSWeakTimer) {
        guard !isRefreshTimerPaused else { return }
        
        refreshTasks()
    }
    
}

// MARK: - UITableViewDataSource
extension TaksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return taskStats?.count ?? 0
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
        guard let task = taskStats?[indexPath.row] else {
            return
        }
        
        let taskCell = cell as! TasksTableViewCell
        taskCell.set(task: task)
    }
}

// MARK: - UITableViewDelegate
extension TaksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

