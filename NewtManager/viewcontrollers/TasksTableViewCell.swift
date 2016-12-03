//
//  TasksTableViewCell.swift
//  NewtManager
//
//  Created by Antonio García on 03/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class TasksTableViewCell: UITableViewCell {

    @IBOutlet weak var priorityLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var runTimeLabel: UILabel!
    @IBOutlet weak var switchesLabel: UILabel!
    @IBOutlet weak var stackUsedLabel: UILabel!
    @IBOutlet weak var stackSizeLabel: UILabel!
    
    private let numberFormatter = NumberFormatter()

    override func awakeFromNib() {
        super.awakeFromNib()
        
        numberFormatter.numberStyle = .decimal
        
        priorityLabel.layer.cornerRadius = 8
        priorityLabel.layer.masksToBounds = true
        priorityLabel.layer.borderColor = UIColor.black.cgColor
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func set(task: NewtTaskStats) {
        priorityLabel.text = String(task.priority)
        nameLabel.text = task.name
        
        runTimeLabel.text = format(value: task.runTime)
        switchesLabel.text = format(value: task.contextSwichCount)
        stackUsedLabel.text = format(value: task.stackUsed)
        stackSizeLabel.text = format(value: task.stackSize)
    }
    
    private func format(value: UInt) -> String {
        var number: NSNumber
        
        let useMillions = value > 100000
        if useMillions {
            number = NSNumber(value: Double(value) / 100000 )
        }
        else {
            
            number = NSNumber(value: value)
        }
        
        return (numberFormatter.string(from: number) ?? "" ) + (useMillions ? "M":"")
    }
}
