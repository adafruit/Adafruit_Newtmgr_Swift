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
    
    
    enum PreferencesNotifications: String {
        case DidUpdatePreferences = "didUpdatePreferences"          // Note: used on some objective-c code, so when changed, update it
    }
    
    // MARK: - Scanning Filters
    static var scanFilterIsPanelOpen: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsPanelOpenKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsPanelOpenKey, newValue: newValue)
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
            return getBoolPreference(key: Preferences.scanFilterIsNameExactKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsNameExactKey, newValue: newValue)
        }
    }

    static var scanFilterIsNameCaseInsensitive: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsNameCaseInsensitiveKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsNameCaseInsensitiveKey, newValue: newValue)
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
            return getBoolPreference(key: Preferences.scanFilterIsUnnamedEnabledKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsUnnamedEnabledKey, newValue: newValue)
        }
    }
    
    static var scanFilterIsOnlyWithUartEnabled: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsOnlyWithUartEnabledKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsOnlyWithUartEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Common
    static func getBoolPreference(key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: key)
    }
    
    static func setBoolPreference(key: String, newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: key)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: PreferencesNotifications.DidUpdatePreferences.rawValue), object: nil);
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

