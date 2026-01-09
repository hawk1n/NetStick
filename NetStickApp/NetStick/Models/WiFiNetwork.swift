//
//  WiFiNetwork.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//
//  Wi-Fi network model
//  Protocol spec: README_PROTOCOL.md

import Foundation

/// Security type for Wi-Fi networks
enum WiFiSecurity: String, CaseIterable {
    case open = "OPEN"
    case wep = "WEP"
    case wpa = "WPA"
    case wpa2 = "WPA2"
    case wpa3 = "WPA3"
    case unknown = "UNKNOWN"
    
    var displayName: String {
        switch self {
        case .open: return "Open"
        case .wep: return "WEP"
        case .wpa: return "WPA"
        case .wpa2: return "WPA2"
        case .wpa3: return "WPA3"
        case .unknown: return "Unknown"
        }
    }
    
    var isSecure: Bool {
        self != .open
    }
    
    init(fromEncryption encryption: String) {
        let upper = encryption.uppercased()
        if upper.contains("WPA3") {
            self = .wpa3
        } else if upper.contains("WPA2") {
            self = .wpa2
        } else if upper.contains("WPA") {
            self = .wpa
        } else if upper.contains("WEP") {
            self = .wep
        } else if upper == "OPEN" || upper.isEmpty {
            self = .open
        } else {
            self = .unknown
        }
    }
}

/// Represents a discovered Wi-Fi network
struct WiFiNetwork: Identifiable, Hashable {
    let id = UUID()
    let ssid: String
    let rssi: Int
    let bssid: String
    let channel: Int
    let security: WiFiSecurity
    
    /// Backward compatibility
    var isSecure: Bool {
        security.isSecure
    }
    
    /// Encryption string for display
    var encryptionString: String {
        security.displayName
    }
    
    /// Signal strength level (0-4)
    var signalLevel: Int {
        switch rssi {
        case -50...0:
            return 4
        case -60...(-50):
            return 3
        case -70...(-60):
            return 2
        case -80...(-70):
            return 1
        default:
            return 0
        }
    }
    
    /// Human-readable signal description
    var signalDescription: String {
        switch signalLevel {
        case 4: return "Excellent"
        case 3: return "Good"
        case 2: return "Fair"
        case 1: return "Weak"
        default: return "Very Weak"
        }
    }
    
    /// Create from DTO (new protocol)
    init(from dto: WiFiNetworkDTO) {
        self.ssid = dto.ssid.isEmpty ? "[Hidden]" : dto.ssid
        self.rssi = dto.rssi
        self.bssid = dto.bssid
        self.channel = dto.channel
        self.security = WiFiSecurity(fromEncryption: dto.encryption)
    }
    
    /// Manual initializer for previews
    init(ssid: String, rssi: Int, bssid: String, channel: Int, isSecure: Bool) {
        self.ssid = ssid
        self.rssi = rssi
        self.bssid = bssid
        self.channel = channel
        self.security = isSecure ? .wpa2 : .open
    }
    
    /// Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(bssid)
    }
    
    static func == (lhs: WiFiNetwork, rhs: WiFiNetwork) -> Bool {
        lhs.bssid == rhs.bssid
    }
}
