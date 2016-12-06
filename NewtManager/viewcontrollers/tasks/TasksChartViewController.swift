//
//  TasksChartViewController.swift
//  NewtManager
//
//  Created by Antonio on 05/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class TasksChartViewController: UIViewController {

    @IBOutlet weak var stackUsageChartView: StackUsageChartView!
    @IBOutlet weak var runtimeChartView: RuntimeChartView!
    @IBOutlet weak var runtimeDeltaChartView: RuntimeChartView!
    @IBOutlet weak var runtimeDeltaLabel: UILabel!

    var stackItems: [StackUsage]? {
        get {
            return stackUsageChartView.items
        }
        
        set {
            stackUsageChartView.items = newValue
        }
    }
    
    var runtimeItems: [UInt]? {
        get {
            return runtimeChartView.items
        }
        
        set {
            let deltaValues = runtimeChartView.items
            
            runtimeChartView.items = newValue
            
            if var deltaValues = deltaValues, let newValue = newValue, deltaValues.count >= newValue.count {
                for i in 0..<newValue.count {
                    deltaValues[i] = max(0, newValue[i] - deltaValues[i])
                    //DLog("delta: \(deltaValues[i])")
                }
                
                runtimeDeltaChartView.items = deltaValues
                //DLog("---")
            }
            else {
                runtimeDeltaChartView.items = nil
            }
        }
    }
    
    var chartColors: [UIColor]? {
        get {
            return stackUsageChartView.chartColors
        }
        
        set {
            stackUsageChartView.chartColors = newValue
            runtimeChartView.chartColors = newValue
            runtimeDeltaChartView.chartColors = newValue
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

       // stackUsageChartView.layer.borderColor = UIColor.black.cgColor
       // stackUsageChartView.layer.borderWidth = 1
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
    
    func hideRunTimeDelta(_ isHidden: Bool) {
        runtimeDeltaChartView.isHidden = isHidden
        runtimeDeltaLabel.isHidden = isHidden
    }

}
