//
//  UartLogManager.swift
//  Calibration
//
//  Created by Antonio García on 24/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class UartLogManager {
    
    enum LogType {
        case info
        case uartTx
        case uartRx
        
        var description: String {
            switch self {
            case .info: return ""
            case .uartTx: return "sent"
            case .uartRx: return "received"
            }
        }
    }
    
    struct LogItem {
        var type = LogType.info
        var data: Data
    }
    
    static var logItems = [LogItem]()

    static func log(data: Data, type: LogType) {
        let item = LogItem(type: type, data: data)
        UartLogManager.logItems.append(item)
    }
    
    static func log(message: String, type: LogType = .info) {
        if let data = message.data(using: .utf8) {
            let item = LogItem(type: type, data: data)
            UartLogManager.logItems.append(item)
        }
    }
    
    static func clearLog() {
        UartLogManager.logItems.removeAll()
    }
}
