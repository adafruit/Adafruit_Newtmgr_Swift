//
//  SensorsEvent.swift
//  Calibration
//
//  Created by Antonio García on 17/11/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

struct Sensor {
    enum SensorType: Int32 {
        case accelerometer = 1
        case magneticField = 2
        case orientation = 3
        case gyroscope = 4
        case light = 5

        /*
        SENSOR_TYPE_PRESSURE              = (6),
        SENSOR_TYPE_PROXIMITY             = (8),
        SENSOR_TYPE_GRAVITY               = (9),
        SENSOR_TYPE_LINEAR_ACCELERATION   = (10),
        SENSOR_TYPE_ROTATION_VECTOR       = (11),
        SENSOR_TYPE_RELATIVE_HUMIDITY     = (12),
        SENSOR_TYPE_AMBIENT_TEMPERATURE   = (13),
        SENSOR_TYPE_VOLTAGE               = (15),
        SENSOR_TYPE_CURRENT               = (16),
        SENSOR_TYPE_COLOR                 = (17)
 */
    }
    
    struct Event {
        var version: Int32
        var sensorId: Int32
        var type: SensorType
        //var reserverd0: Int32
        private var dataBytes: Data
        
        init(fromData bytes: Data) {
            version = bytes.scanValue(start: 0, length: 4)
            sensorId = bytes.scanValue(start: 4, length: 4)
            type = bytes.scanValue(start: 8, length: 4)
            //reserverd0 = bytes.scanValue(start: 12, length: 4)
            dataBytes = bytes.subdata(in: 16..<bytes.count)
        }
        
        var data: [Float32] {
            var result = [Float]()
            for i in 0..<4 {
                result[i] = dataBytes.scanValue(start: i*4, length: 4)
            }
            
            return result
        }
        
        private var float32Value: Float32 {
            return dataBytes.scanValue(start: 0, length: 4)
        }
        
        var acceleration: Vector {
            return Vector(fromData: dataBytes)
        }
        
        var magnetic: Vector {
            return Vector(fromData: dataBytes)
        }
        
        var orientation: Vector {
            return Vector(fromData: dataBytes)
        }
        
        var gyro: Vector {
            return Vector(fromData: dataBytes)
        }
        
        var temperature: Float32 {
            return float32Value
        }
        
        
        struct Vector {
            private var dataBytes: Data
            var status: Int8
            //var reserved0: Int8
            //var reserved1: Int8
            //var reserved2: Int8
            
            init(fromData bytes: Data) {
                dataBytes = bytes.subdata(in: 0..<12)
                status = bytes.scanValue(start: 12, length: 1)
                //reserverd0 = bytes.scanValue(start: 13, length: 4)
                //reserverd1 = bytes.scanValue(start: 17, length: 4)
                //reserverd2 = bytes.scanValue(start: 21, length: 4)
            }
            
            var v: [Float32] {
                var result = [Float]()
                for i in 0..<3 {
                    result[i] = dataBytes.scanValue(start: i*4, length: 4)
                }
                
                return result
            }
            
            var vector: (x: Float32, y: Float32, z: Float32) {
                let temp = v
                return (x: temp[0], y: temp[1], z: temp[2])
            }
            
            var orientation: (roll: Float32, pitch: Float32, heading: Float32) {
                let temp = v
                return (roll: temp[0], pitch: temp[1], heading: temp[2])
            }
        }
    }
}

