//
//  NetworkDevice.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import Foundation

/// Represents a device discovered during network scan
struct NetworkDevice: Identifiable, Hashable {
    let id = UUID()
    let ip: String
    let mac: String
    let vendor: String
    var ports: [OpenPort] = []
    var vulnerabilities: [Vulnerability] = []
    
    /// Check if device has any open ports
    var hasOpenPorts: Bool {
        !ports.isEmpty
    }
    
    /// Check if device has any vulnerabilities
    var hasVulnerabilities: Bool {
        !vulnerabilities.isEmpty
    }
    
    /// Maximum severity level of all vulnerabilities
    var maxSeverity: Int {
        vulnerabilities.map { $0.severity }.max() ?? 0
    }
    
    /// Risk level based on ports and vulnerabilities
    var riskLevel: RiskLevel {
        if maxSeverity >= 9 {
            return .critical
        } else if maxSeverity >= 7 {
            return .high
        } else if maxSeverity >= 4 {
            return .medium
        } else if hasOpenPorts {
            return .low
        }
        return .none
    }
    
    /// Device type guess based on vendor
    var deviceType: DeviceType {
        let vendorLower = vendor.lowercased()
        
        if vendorLower.contains("apple") {
            return .apple
        } else if vendorLower.contains("samsung") {
            return .phone
        } else if vendorLower.contains("espressif") || vendorLower.contains("raspberry") || vendorLower.contains("arduino") {
            return .iot
        } else if vendorLower.contains("cisco") || vendorLower.contains("netgear") || vendorLower.contains("tp-link") {
            return .router
        } else if vendorLower.contains("intel") || vendorLower.contains("dell") || vendorLower.contains("hp") || vendorLower.contains("lenovo") {
            return .computer
        }
        
        return .unknown
    }
    
    static func == (lhs: NetworkDevice, rhs: NetworkDevice) -> Bool {
        lhs.ip == rhs.ip && lhs.mac == rhs.mac
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ip)
        hasher.combine(mac)
    }
}

/// Risk level for devices
enum RiskLevel: Int, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var color: String {
        switch self {
        case .none: return "green"
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .none: return "Safe"
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        case .critical: return "Critical"
        }
    }
}

/// Device type for icon selection
enum DeviceType {
    case router
    case computer
    case phone
    case apple
    case iot
    case unknown
    
    var iconName: String {
        switch self {
        case .router: return "wifi.router.fill"
        case .computer: return "desktopcomputer"
        case .phone: return "iphone"
        case .apple: return "apple.logo"
        case .iot: return "sensor.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
