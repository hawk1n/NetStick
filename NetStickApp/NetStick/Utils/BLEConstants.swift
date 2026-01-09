//
//  BLEConstants.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import CoreBluetooth

enum BLEConstants {
    // Nordic UART Service UUID
    static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // RX Characteristic - Client WRITES commands here
    static let rxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // TX Characteristic - Client RECEIVES responses here (via notifications)
    static let txUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // BLE MTU limit - device does NOT handle fragmentation
    static let maxPayloadSize = 180
    
    // Timeout values
    static let wifiScanTimeout: TimeInterval = 8
    static let networkScanTimeout: TimeInterval = 20
    static let portScanTimeout: TimeInterval = 60
}
