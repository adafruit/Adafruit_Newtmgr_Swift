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

struct NewtTaskStats {
    var taskId: UInt
    var name: String
    var priority: UInt
    var state: UInt
    var runTime: UInt
    var contextSwichCount: UInt
    var stackSize: UInt
    var stackUsed: UInt
    var lastSanityCheckin: UInt
    var nextSanityCheckin: UInt
}

enum NewtError: Error {
    case invalidCharacteristic
    case enableNotifyFailed
    case receivedResponseIsNotAPacket
    case receivedResponseIsNotAJson(Error?)
    case receivedResponseMissingFields
    case receviedResponseInvalidValues
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
        case .receivedResponseMissingFields: return "Received Json with missing fields"
        case .receviedResponseInvalidValues: return "Received Json with invalid values"
        case .receivedResultNotOk(let message): return "Received incorrect result: \(message)"
        case .internalError: return "Internal error"
        case .updateImageInvalid: return "Upload image is invalid"
        case .imageInvalid: return "Image invalid"
        case .userCancelled: return "Cancelled"
        case .waitingForReponse: return "Waiting for previous command"
        }
    }
}

