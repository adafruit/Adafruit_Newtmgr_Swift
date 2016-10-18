//
//  DataConversions.swift
//  NewtManager
//
//  Created by Antonio García on 15/10/16.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation


func hexDescription(data: Data, prefix: String = "", postfix: String = " ") -> String{
    return data.reduce("") {$0 + String(format: "%@%02X%@", prefix, $1, postfix)}
}

func decimalDescription(data: Data, prefix: String = "", postfix: String = " ") -> String{
    return data.reduce("") {$0 + String(format: "%@%ld%@", prefix, $1, postfix)}
}
