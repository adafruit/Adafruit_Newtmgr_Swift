//
//  TaskViewController.swift
//  NewtManager
//
//  Created by Antonio García on 03/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class TaskViewController: UIViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!

    // Data
    fileprivate static let kItemNames = ["Priority", "Task ID", "Runtime", "Context Switches", "Stack Size", "Stack Used", "Last Sanity Check", "Next Sanity Check"]
    private let numberFormatter = NumberFormatter()

    var task: NewtHandler.TaskStats?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        numberFormatter.numberStyle = .decimal
        
        self.title = task?.name
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    fileprivate func format(value: UInt) -> String {
        let number =  NSNumber(value: value)
        return (numberFormatter.string(from: number) ?? "" )
    }
}

// MARK: - UITableViewDataSource
extension TaskViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TaskViewController.kItemNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "TaskCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let task = task else { return }
        
        var detailText: String?
        switch indexPath.row {
        case 0: detailText = String(task.priority)
        case 1: detailText = String(task.taskId)
        case 2: detailText = format(value: task.runTime)
        case 3: detailText = format(value: task.contextSwichCount)
        case 4: detailText = format(value: task.stackSize)
        case 5: detailText = format(value: task.stackUsed)
        case 6: detailText = format(value: task.lastSanityCheckin)
        case 7: detailText = format(value: task.nextSanityCheckin)
        default:
            detailText = nil
        }
        
        cell.textLabel?.text = TaskViewController.kItemNames[indexPath.row]
        cell.detailTextLabel?.text = detailText
        cell.selectionStyle = .none
    }
}

// MARK: - UITableViewDelegate
extension TaskViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
