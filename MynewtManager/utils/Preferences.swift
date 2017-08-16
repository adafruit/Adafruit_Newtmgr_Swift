//
//  Preferences.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit
#else       // iOS, tvOS
    import UIKit
#endif

class Preferences {
    // Note: if these contanst change, update DefaultPreferences.plist
    private static let scanFilterIsPanelOpenKey = "ScanFilterIsPanelOpen"
    private static let scanFilterNameKey = "ScanFilterName"
    private static let scanFilterIsNameExactKey = "ScanFilterIsNameExact"
    private static let scanFilterIsNameCaseInsensitiveKey = "ScanFilterIsNameCaseInsensitive"
    private static let scanFilterRssiValueKey = "ScanFilterRssiValue"
    private static let scanFilterIsUnnamedEnabledKey = "ScanFilterIsUnnamedEnabled"
    private static let scanFilterIsOnlyWithUartEnabledKey = "ScanFilterIsOnlyWithUartEnabled"
    
    // Uart
    fileprivate static let uartIsDisplayModeTimestampKey = "UartIsDisplayModeTimestamp"
    fileprivate static let uartIsInHexModeKey = "UartIsInHexMode"
    fileprivate static let uartIsEchoEnabledKey = "UartIsEchoEnabled"
    fileprivate static let uartIsAutomaticEolEnabledKey = "UartIsAutomaticEolEnabled"
    fileprivate static let uartShowInvisibleCharsKey = "UartShowInvisibleChars"

    
    // MARK: - Scanning Filters
    static var scanFilterIsPanelOpen: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsPanelOpenKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsPanelOpenKey, newValue: newValue)
        }
    }

    static var scanFilterName: String? {
        get {
            let defaults = UserDefaults.standard
            return defaults.string(forKey: Preferences.scanFilterNameKey)
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: Preferences.scanFilterNameKey)
        }
    }
    
    static var scanFilterIsNameExact: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsNameExactKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsNameExactKey, newValue: newValue)
        }
    }

    static var scanFilterIsNameCaseInsensitive: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsNameCaseInsensitiveKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsNameCaseInsensitiveKey, newValue: newValue)
        }
    }

    static var scanFilterRssiValue: Int? {
        get {
            let defaults = UserDefaults.standard
            let rssiValue = defaults.integer(forKey: Preferences.scanFilterRssiValueKey)
            return rssiValue >= 0 ? rssiValue:nil
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue ?? -1, forKey: Preferences.scanFilterRssiValueKey)
        }
    }
    
    static var scanFilterIsUnnamedEnabled: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsUnnamedEnabledKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsUnnamedEnabledKey, newValue: newValue)
        }
    }
    
    static var scanFilterIsOnlyWithUartEnabled: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsOnlyWithUartEnabledKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsOnlyWithUartEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Uart
    static var uartShowInvisibleChars: Bool {
        get {
            return getBoolPreference(Preferences.uartShowInvisibleCharsKey)
        }
        set {
            setBoolPreference(Preferences.uartShowInvisibleCharsKey, newValue: newValue)
        }
    }
    
    static var uartIsDisplayModeTimestamp: Bool {
        get {
            return getBoolPreference(Preferences.uartIsDisplayModeTimestampKey)
        }
        set {
            setBoolPreference(Preferences.uartIsDisplayModeTimestampKey, newValue: newValue)
        }
    }
    
    static var uartIsInHexMode: Bool {
        get {
            return getBoolPreference(Preferences.uartIsInHexModeKey)
        }
        set {
            setBoolPreference(Preferences.uartIsInHexModeKey, newValue: newValue)
        }
    }
    
    static var uartIsEchoEnabled: Bool {
        get {
            return getBoolPreference(Preferences.uartIsEchoEnabledKey)
        }
        set {
            setBoolPreference(Preferences.uartIsEchoEnabledKey, newValue: newValue)
        }
    }
    
    static var uartIsAutomaticEolEnabled: Bool {
        get {
            return getBoolPreference(Preferences.uartIsAutomaticEolEnabledKey)
        }
        set {
            setBoolPreference(Preferences.uartIsAutomaticEolEnabledKey, newValue: newValue)
        }
    }

    
    // MARK: - Common
    static func getBoolPreference(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: key)
    }
    
    static func setBoolPreference(_ key: String, newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: key)
        NotificationCenter.default.post(name: .didUpdatePreferences, object: nil)
    }
    
    // MARK: - Defaults
    static func registerDefaults() {
        let path = Bundle.main.path(forResource: "DefaultPreferences", ofType: "plist")!
        let defaultPrefs = NSDictionary(contentsOfFile: path) as! [String : AnyObject]
        
        UserDefaults.standard.register(defaults: defaultPrefs)
    }
    
    static func resetDefaults() {
        let appDomain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: appDomain)
    }
}


// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    
    static let  didUpdatePreferences = Notification.Name(kPrefix+".didUpdatePreferences")
}

