//
//  LogHelper.swift


import Foundation

func DLog(_ message: String, function: String = #function) {
    #if !NDEBUG
        NSLog("%@, %@", function, message)
    #endif
}
