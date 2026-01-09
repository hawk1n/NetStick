//
//  BLECommand.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//
//  Simple JSON command protocol for M5Stick communication
//  Protocol spec: README_PROTOCOL.md

import Foundation

struct WiFiScanParams: Codable {
    let duration: Int?
    let mode: String?
    let channels: [Int]?
}

/// Enum representing all BLE commands that can be sent to M5Stick device
enum BLECommand {
    case wifiScan(requestId: String, params: WiFiScanParams?)
    case connect(ssid: String, password: String)
    case networkScan
    case scanPorts(ip: String, startPort: Int, endPort: Int)
    case advancedScan(ip: String, osDetect: Bool, serviceVersion: Bool)
    case analyze(ip: String)
    case status
    case cancel
    
    static func generateRequestId() -> String {
        return UUID().uuidString
    }
    
    /// Convert command to JSON string
    func toJSON() -> String? {
        var dict: [String: Any] = [:]
        
        switch self {
        case .wifiScan(let requestId, let params):
            dict["cmd"] = "wifi_scan"
            dict["request_id"] = requestId
            if let params = params {
                if let d = params.duration { dict["duration"] = d }
                if let m = params.mode { dict["mode"] = m }
                if let c = params.channels { dict["channels"] = c }
            }
            
        case .connect(let ssid, let password):
            dict["cmd"] = "wifi_connect"
            dict["ssid"] = ssid
            dict["password"] = password
            
        case .networkScan:
            dict["cmd"] = "network_scan"
            
        case .scanPorts(let ip, let startPort, let endPort):
            dict["cmd"] = "port_scan"
            dict["target"] = ip
            dict["start"] = startPort
            dict["end"] = endPort
            
        case .advancedScan(let ip, let osDetect, let serviceVersion):
            dict["cmd"] = "advanced_scan"
            dict["target"] = ip
            dict["osDetect"] = osDetect
            dict["serviceVersion"] = serviceVersion
            
        case .analyze(let ip):
            dict["cmd"] = "analyze"
            dict["target"] = ip
            
        case .status:
            dict["cmd"] = "status"
            
        case .cancel:
            dict["cmd"] = "cancel"
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        // Validate size
        let byteCount = jsonString.utf8.count
        if byteCount > BLEConstants.maxPayloadSize {
            print("⚠️ Command too large: \(byteCount) bytes (max: \(BLEConstants.maxPayloadSize))")
            return nil
        }
        
        return jsonString
    }
    
    /// Command name for logging
    var commandName: String {
        switch self {
        case .wifiScan: return "wifi_scan"
        case .connect: return "wifi_connect"
        case .networkScan: return "network_scan"
        case .scanPorts: return "port_scan"
        case .advancedScan: return "advanced_scan"
        case .analyze: return "analyze"
        case .status: return "status"
        case .cancel: return "cancel"
        }
    }
}

extension BLECommand {
    /// Human-readable description of the command
    var description: String {
        switch self {
        case .wifiScan:
            return "Wi-Fi Scan"
        case .connect(let ssid, _):
            return "Connect to \(ssid)"
        case .networkScan:
            return "Network Scan"
        case .scanPorts(let ip, _, _):
            return "Port Scan \(ip)"
        case .advancedScan(let ip, _, _):
            return "Advanced Scan \(ip)"
        case .analyze(let ip):
            return "Analyze \(ip)"
        case .status:
            return "Status Check"
        case .cancel:
            return "Cancel Operation"
        }
    }
}
