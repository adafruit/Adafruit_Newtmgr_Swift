//
//  Newt.swift
//  NewtManager
//
//  Created by Antonio García on 02/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

struct NewtImage {
    var slot: Int
    var version: String
    var isConfirmed: Bool
    var isPending: Bool
    var isActive: Bool
    var isBootable: Bool
    var hash: Data
}

enum NewtError: Error {
    case invalidCharacteristic
    case enableNotifyFailed
    case receivedResponseIsNotAPacket
    case receivedResponseIsNotAJson(Error?)
    case receivedResponseJsonMissingFields
    case receviedResponseJsonInvalidValues
    case receivedResultNotOk(String)
    case internalError
    case updateImageInvalid
    case imageInvalid
    case userCancelled
    case waitingForReponse
    
    var description: String {
        switch self {
        case .invalidCharacteristic: return "Newt characteristic is invalid"
        case .enableNotifyFailed: return "Cannot enable notification on Newt characteristic"
        case .receivedResponseIsNotAPacket: return "Received response is not a packet"
        case .receivedResponseIsNotAJson(let error): return "Received invalid Json: \(error?.localizedDescription ?? "")"
        case .receivedResponseJsonMissingFields: return "Received Json with missing fields"
        case .receviedResponseJsonInvalidValues: return "Received Json with invalid values"
        case .receivedResultNotOk(let message): return "Received incorrect result: \(message)"
        case .internalError: return "Internal error"
        case .updateImageInvalid: return "Upload image is invalid"
        case .imageInvalid: return "Image invalid"
        case .userCancelled: return "Cancelled"
        case .waitingForReponse: return "Waiting for previous command"
        }
    }
}




extension BlePeripheral {
 
    
    
}
