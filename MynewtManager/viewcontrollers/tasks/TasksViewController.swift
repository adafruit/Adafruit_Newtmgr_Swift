//
//  TaksViewController.swift
//  MynewtManager
//
//  Created by Antonio García on 14/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import MSWeakTimer
import Charts

class TaksViewController: NewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private let refreshControl = UIRefreshControl()
    @IBOutlet weak var playButton: UIBarButtonItem!
    @IBOutlet weak var chartContainerView: UIView!
 
    // Data
    fileprivate var taskStats: [NewtHandler.TaskStats]?
    fileprivate var autoRefresh: AutoRefresh!
    fileprivate var chartColors = [UIColor]()

    fileprivate var tasksChartViewController: TasksChartViewController?
    private weak var taskViewController: TaskViewController?
    fileprivate var selectedTaskId: UInt?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        baseTableView.contentInset = UIEdgeInsets(top: -10, left: 0, bottom: 0, right: 0)

        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)

        // Pie Chart
        chartColors.append(contentsOf: ChartColorTemplates.colorful())
        chartColors.append(contentsOf: ChartColorTemplates.joyful())
        tasksChartViewController?.chartColors = chartColors

/*
        chartView.rotationAngle = 270-50       // To avoid ugly starting lines
        setupChart()
        chartView.animate(xAxisDuration: 1.4)
  */

        autoRefresh = AutoRefresh(onFired: refreshTasks)
        tasksChartViewController?.hideRunTimeDelta(true)
        updateUI()
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
        
        autoRefresh.isPaused = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        autoRefresh.isPaused = true && taskViewController == nil
    }
    
    deinit {
        autoRefresh.stop()
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let taskViewController = segue.destination as? TaskViewController, let taskStats = taskStats, let selectedIndex = baseTableView.indexPathForSelectedRow?.row {
            self.taskViewController = taskViewController
            taskViewController.task = taskStats[selectedIndex]
            taskViewController.setPlaying(autoRefresh.isStarted)
            taskViewController.delegate = self
        }
        else if let tasksChartViewController = segue.destination as? TasksChartViewController {
            self.tasksChartViewController = tasksChartViewController
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
            
            if let taskStats = taskStats as? [NewtHandler.TaskStats] {
                context.setTaskStats(taskStats)
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
    }
    
    private func setTaskStats(_ taskStats: [NewtHandler.TaskStats]) {
        let sortedTasks = taskStats.sorted(by: {$0.priority < $1.priority})
        self.taskStats = sortedTasks
        
        // Update child (if pushed)
        guard let selectedTaskId = selectedTaskId, let task = taskStats.first(where: {$0.taskId == selectedTaskId}) else { return }
        taskViewController?.task = task
    }


    // MARK: - Charts
    private func updateCharts() {
        guard let taskStats = taskStats else {
            chartContainerView.isHidden = true
            return
        }
        chartContainerView.isHidden = false
        
        // Pie Chart
        // updatePieChart()
        
        
        // Stack Usage Chart
        var stackItems: [StackUsage] = []
        var runtimeItems: [UInt] = []
        for task in taskStats {
            let used = task.stackUsed
            let total = task.stackSize
            
            stackItems.append(StackUsage(used: used, total: total))
            
            runtimeItems.append(task.runTime)
        }
        
        tasksChartViewController?.stackItems = stackItems

        // Runtime Data
        tasksChartViewController?.runtimeItems = runtimeItems
        
    }
/*
    // MARK: - PieChart
    private func setupChart() {
        
        chartTitleLabel.text = "Stack Size"
        chartView.legend.enabled = false
        
        chartView.chartDescription?.enabled = false
        //chartView.legend.drawInside = true
        
        //chartView.maxAngle = 180                // Half chart
        //chartView.rotationAngle = 180           // Rotate to make the half on the upper side
        //chartView.centerTextOffset = CGPoint(x: 0, y: 0)
        //        chartView.contentScaleFactor = 2.5
        //chartView.holeRadiusPercent = 0.30
        
        //chartView.extraTopOffset = 20
        // chartView.extraBottomOffset = -20
        
        chartView.rotationEnabled = true
        chartView.highlightPerTapEnabled = false
        // chartView.drawSlicesUnderHoleEnabled = false
        
        chartView.entryLabelColor = UIColor.black
        
        //chartView.usePercentValuesEnabled = true
    }
    
    
    private func updatePieChart() {
        guard let taskStats = taskStats else {
            chartView.data = nil
            chartContainerView.isHidden = true
            return
        }
        chartContainerView.isHidden = false
        
        // Entries
        var pieChartEntries = [PieChartDataEntry]()
        for task in taskStats {
                let value = Double(task.stackSize)
                //DLog("value: \(value)")
                let pieChartEntry = PieChartDataEntry(value: value, label: task.name)
                
                pieChartEntries.append(pieChartEntry)
        }
        
        // DataSet
        let dataSet = PieChartDataSet(values: pieChartEntries, label: "Runtime")
        dataSet.sliceSpace = 2
        dataSet.colors = chartColors
        
        dataSet.yValuePosition = .outsideSlice
        dataSet.valueLinePart1OffsetPercentage = 0.8
        dataSet.valueLinePart1Length = 0.5
        dataSet.valueLinePart2Length = 0.5
        dataSet.valueLineVariableLength = false

        // Data
        let data = PieChartData(dataSet: dataSet)
        
        /*
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .percent
        numberFormatter.maximumFractionDigits = 1
        numberFormatter.percentSymbol = "%"
        let valueFormatter = DefaultValueFormatter(formatter: numberFormatter)
        data.setValueFormatter(valueFormatter)
        */
        
        data.setValueTextColor(UIColor.black)
        data.setValueFont(UIFont.systemFont(ofSize: 12))
        chartView.data = data
        
    }
   */
    
    // MARK: - UI
    func onTableRefresh(_ sender: AnyObject) {
        refreshTasks()
        refreshControl.endRefreshing()
    }
    
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
        updateCharts()
    }
    
    // MARK: - Auto Refresh
    @IBAction func onClickPlay(_ sender: Any) {

        if !autoRefresh.isStarted {
            autoRefresh.start()
            playButton.image = UIImage(named: "ic_pause_circle_outline")
            tasksChartViewController?.hideRunTimeDelta(false)
            taskViewController?.setPlaying(true)
        }
        else {
            autoRefresh.stop()
            playButton.image = UIImage(named: "ic_play_circle_outline")
            tasksChartViewController?.hideRunTimeDelta(true)
            taskViewController?.setPlaying(false)            
        }
    }
}

// MARK: - UITableViewDataSource
extension TaksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return taskStats?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "TaskCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let task = taskStats?[indexPath.row] else {
            return
        }

        let color = chartColors[indexPath.row % chartColors.count]
        let taskCell = cell as! TasksTableViewCell
        taskCell.set(task: task, color: color)
    }
}

// MARK: - UITableViewDelegate
extension TaksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        selectedTaskId = taskStats?[indexPath.row].taskId
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - TaskViewControllerDelegate
extension TaksViewController: TaskViewControllerDelegate {
    func onClickPlayPause() {
        onClickPlay(self)
    }
    
    func onTaskDetailWillAppear() {
        autoRefresh.isPaused = false
    }
    
    func onTaskDetailDidDissapear() {
        autoRefresh.isPaused = true && view.window == nil
    }
}

