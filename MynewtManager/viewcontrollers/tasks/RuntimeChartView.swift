//
//  RuntimeChartView.swift
//  MynewtManager
//
//  Created by Antonio on 05/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class RuntimeChartView: UIView {

    // Data
    var chartColors: [UIColor]? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var items: [UInt]? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // MARK: - View Lifecycle
    override func layoutSubviews() {
        super.layoutSubviews()
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let chartColors = chartColors, let items = items, let context = UIGraphicsGetCurrentContext() else { return }
        context.setAllowsAntialiasing(true)
        
        let kItemSeparation: CGFloat = 4
        let viewWidth = rect.size.width - CGFloat(items.count - 1) * kItemSeparation
        let sumTotals = items.reduce(0, +)
        var offsetX: CGFloat = 0
        for (i, runtime) in items.enumerated() {
            
            let totalFactor = CGFloat(runtime) / CGFloat(sumTotals)
            let totalColor = chartColors[i%chartColors.count]
            let itemWidth = viewWidth  * totalFactor

            // Total
            let rectangleTotal = CGRect(x: offsetX, y: 0, width: itemWidth, height: rect.size.height)
            context.setFillColor(totalColor.cgColor)
            context.addRect(rectangleTotal)
            context.fillPath()
            
            offsetX = offsetX + itemWidth + kItemSeparation
        }
    }

}
