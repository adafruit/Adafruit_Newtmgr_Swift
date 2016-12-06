//
//  StackUsageChartView.swift
//  NewtManager
//
//  Created by Antonio on 05/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

struct StackUsage {
    var used: UInt
    var total: UInt
}


class StackUsageChartView: UIView {
    
    var chartColors: [UIColor]? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var items: [StackUsage]? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let chartColors = chartColors, let usageData = items, let context = UIGraphicsGetCurrentContext() else { return }
        context.setAllowsAntialiasing(true)

        let kItemSeparation: CGFloat = 4
        let viewWidth = rect.size.width - CGFloat(usageData.count - 1) * kItemSeparation
        let sumTotals = usageData.reduce(0, {$0 + $1.total})
        let font = UIFont.boldSystemFont(ofSize: UIFont.smallSystemFontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let textAttributes = [NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.black, NSParagraphStyleAttributeName: paragraphStyle] as [String : Any]

        var offsetX: CGFloat = 0
        for (i, item) in usageData.enumerated() {
            if item.total != 0 {
                context.saveGState()

                let totalFactor = CGFloat(item.total) / CGFloat(sumTotals)
                let itemWidth = viewWidth  * totalFactor
                let usageFactor = CGFloat(item.used) / CGFloat(item.total)
                let usageWidth = itemWidth * usageFactor
                let totalColor = chartColors[i%chartColors.count]
                let usageColor = chartColors[i%chartColors.count].lighter()
                
                // Used
                let rectangleUsed = CGRect(x: offsetX, y: 0, width: usageWidth, height: rect.size.height)
                context.setFillColor(totalColor.cgColor)
                context.addRect(rectangleUsed)
                context.fillPath()

                // Total
                let rectangleTotal = CGRect(x: offsetX+usageWidth, y: 0, width: itemWidth-usageWidth, height: rect.size.height)
                context.setFillColor(usageColor.cgColor)
                context.addRect(rectangleTotal)
                context.fillPath()

                let text = "\(item.used)/\(item.total)"
             //   DLog(text)
                
                // Text
                context.saveGState()
//                context.scaleBy(x: 1, y: -1)
                context.translateBy(x: font.lineHeight/2, y: rect.size.height/2)
                context.rotate(by: -.pi/2)
                context.translateBy(x:-rect.size.height/2 , y: -font.lineHeight/2)
                
                //context.setLineWidth(1)
                //context.setStrokeColor(totalColor.cgColor)
                let rect = CGRect(x: 0, y: offsetX + itemWidth - font.lineHeight, width: rect.size.height, height: font.lineHeight)
                //context.addRect(rect)
                //context.strokePath()
                
                //DLog(NSStringFromCGRect(rect))
                text.draw(in: rect, withAttributes: textAttributes)
                
                context.restoreGState()

                offsetX = offsetX + itemWidth + kItemSeparation

                context.restoreGState()
            }
        }
    }
}
