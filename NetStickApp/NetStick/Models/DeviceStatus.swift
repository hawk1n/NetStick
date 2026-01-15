//
//  DeviceStatus.swift
//  NetStick
//
//  Device status information from M5Stick
//

import Foundation

struct DeviceStatus: Codable {
    let battery: Int
    let charging: Bool
    let wifi: String
    let rssi: Int?
    let stage: String?
    let percent: Int?
    let btConnected: Bool?
    let wifiConnected: Bool?
    let ssid: String?
<<<<<<< HEAD
=======
    let uptimeSeconds: Int?
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
    
    init(
        battery: Int,
        charging: Bool,
        wifi: String,
        rssi: Int? = nil,
        stage: String? = nil,
        percent: Int? = nil,
        btConnected: Bool? = nil,
        wifiConnected: Bool? = nil,
<<<<<<< HEAD
        ssid: String? = nil
=======
        ssid: String? = nil,
        uptime: Int? = nil
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
    ) {
        self.battery = battery
        self.charging = charging
        self.wifi = wifi
        self.rssi = rssi
        self.stage = stage
        self.percent = percent
        self.btConnected = btConnected
        self.wifiConnected = wifiConnected
        self.ssid = ssid
<<<<<<< HEAD
=======
        self.uptimeSeconds = uptime
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
    }
    
    var batteryLevel: BatteryLevel {
        switch battery {
        case 0..<20: return .low
        case 20..<50: return .medium
        case 50..<80: return .good
        default: return .full
        }
    }
    
    var isConnectedToWiFi: Bool {
        (wifiConnected ?? (wifi != "disconnected" && wifi != "unknown"))
    }

    var signalDescription: String {
        guard let rssi else { return "n/a" }
        switch rssi {
        case -50...0: return "Excellent"
        case -65...(-50): return "Good"
        case -75...(-65): return "Fair"
        case -90...(-75): return "Weak"
        default: return "Very Weak"
        }
    }

    var activeStageDescription: String {
        (stage ?? "idle").replacingOccurrences(of: "_", with: " ").capitalized
    }
<<<<<<< HEAD
=======
    
    var uptimeDescription: String {
        guard let uptimeSeconds else { return "n/a" }
        let hours = uptimeSeconds / 3600
        let minutes = (uptimeSeconds % 3600) / 60
        let seconds = uptimeSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
}

enum BatteryLevel {
    case low, medium, good, full
    
    var color: String {
        switch self {
        case .low: return "red"
        case .medium: return "orange"
        case .good: return "yellow"
        case .full: return "green"
        }
    }
    
    var iconName: String {
        switch self {
        case .low: return "battery.25"
        case .medium: return "battery.50"
        case .good: return "battery.75"
        case .full: return "battery.100"
        }
    }
}
