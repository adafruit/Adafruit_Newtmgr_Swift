//
//  AutoRefresh.swift
//  NewtManager
//
//  Created by Antonio on 06/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import MSWeakTimer


class AutoRefresh {
    // Config
    private static let kTimeInterval = 0.5
    
    private var refreshTimer: MSWeakTimer?
    var isPaused = true
    var isStarted: Bool {
        return refreshTimer != nil
    }

    private var onFired: ()->()?
    
    
    init(onFired: @escaping ()->()?) {
        self.onFired = onFired
    }
    
    func start() {
        
        isPaused = false
        refreshTimer = MSWeakTimer.scheduledTimer(withTimeInterval: AutoRefresh.kTimeInterval, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true, dispatchQueue: .main)
    }
    
    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @objc func timerFired(timer: MSWeakTimer) {
        guard !isPaused else { return }
        
        onFired()
    }
    
}
