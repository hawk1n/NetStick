//
//  BLEResponse.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//
//  Response structures for M5Stick BLE protocol
//  Protocol spec: README_PROTOCOL.md

import Foundation

// MARK: - Legacy / Unified Types (Restored for Build)

struct BLEResponse: Codable {
    let type: String
    var message: String? = nil
    var code: Int? = nil
    var details: String? = nil
    var status: String? = nil
    var ble: String? = nil
    var wifi: String? = nil
    var ip: String? = nil
    var battery: Int? = nil
    var charging: Bool? = nil
    var stage: String? = nil
    var percent: Int? = nil
    var operation: String? = nil
    var current: Int? = nil
    var total: Int? = nil
    var rssi: Int? = nil
    var btConnected: Bool? = nil
    var wifiConnected: Bool? = nil
    var ssid: String? = nil
    var progress: Int? = nil
<<<<<<< HEAD
=======
    var uptime: Int? = nil
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
    var networks: [WiFiNetworkDTO]? = nil
    var mac: String? = nil
    var vendor: String? = nil
    var count: Int? = nil
    var port: Int? = nil
    var service: String? = nil
    var banner: String? = nil
    var portProtocol: String? = nil
    var version: String? = nil
    var target: String? = nil
    var start: Int? = nil
    var end: Int? = nil
    var os: String? = nil
    var openPorts: [PortSummaryEntry]? = nil
    var cve: String? = nil
    var severity: Int? = nil
    var description: String? = nil
    var vulns: Int? = nil
    var maxSeverity: Int? = nil
    var cmd: String? = nil
    var requestId: String? = nil
    var timestamp: Int? = nil
    var domain: String? = nil
    var action: String? = nil
    var id: String? = nil
    
    enum CodingKeys: String, CodingKey {
<<<<<<< HEAD
        case type, message, code, details, status, ble, wifi, ip, battery, charging, stage, percent, operation, current, total, rssi, btConnected, wifiConnected, ssid, progress, networks, mac, vendor, count, port, service, banner
=======
        case type, message, code, details, status, ble, wifi, ip, battery, charging, stage, percent, operation, current, total, rssi, btConnected, wifiConnected, ssid, progress, uptime, networks, mac, vendor, count, port, service, banner
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
        case portProtocol = "protocol"
        case version, target, start, end, os, openPorts, cve, severity, description, vulns, maxSeverity, cmd, requestId, timestamp, domain, action, id
    }
    
    var responseType: BLEResponseType? {
        BLEResponseType(rawValue: type)
    }
}

struct VulnerabilityDTO: Codable {
    let cve: String
    let severity: Int
    let description: String
}

struct Ack: Codable {
    let cmd: String?
    let action: String?
    let status: String?
    let message: String?
    let requestId: String?
    let timestamp: Int?
    let domain: String?
    let id: String?
    
    var effectiveRequestId: String? { requestId ?? id }
}

struct ProtoError: Codable {
    let code: Int?
    let message: String
    let details: String?
    let requestId: String?
    let domain: String?
    let id: String?
    
    var effectiveRequestId: String? { requestId ?? id }
}

struct WiFiChunk: Codable {
    let seq: Int
    let total: Int
    let payload: ChunkPayload
    let requestId: String?
    let id: String?
    let crc: String?
    
    var effectiveRequestId: String? { requestId ?? id }
    var isWiFi: Bool { true }
    
    enum ChunkPayload: Codable {
        case networks([WiFiNetworkDTO])
        case encoded(String)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let nets = try? container.decode([WiFiNetworkDTO].self) {
                self = .networks(nets)
                return
            }
            if let str = try? container.decode(String.self) {
                self = .encoded(str)
                return
            }
            throw DecodingError.typeMismatch(ChunkPayload.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected array or string"))
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .networks(let nets): try container.encode(nets)
            case .encoded(let str): try container.encode(str)
            }
        }
    }
}

struct WiFiComplete: Codable {
    let count: Int
    let requestId: String?
    let id: String?
    
    var effectiveRequestId: String? { requestId ?? id }
    var isWiFi: Bool { true }
}

// MARK: - Base Response (for type detection)

struct BaseResponse: Codable {
    let type: String
}

// MARK: - Wi-Fi Scan Results

/// Wi-Fi network from wifi_results response
struct WiFiNetworkDTO: Codable {
    let ssid: String
    let bssid: String
    let rssi: Int
    let channel: Int
    let encryption: String  // "WPA2", "WPA3", "WEP", "OPEN"
    
    /// Compatibility: is network secure
    var secure: Bool {
        encryption.uppercased() != "OPEN"
    }
}

/// Wi-Fi scan results (single event with all networks)
struct WiFiResultsResponse: Codable {
    let type: String  // "wifi_results"
    let networks: [WiFiNetworkDTO]
}

// MARK: - Network Scan (Streaming)

/// Device found during network scan
struct DeviceResponse: Codable {
    let type: String  // "device"
    let ip: String
    let mac: String
    let vendor: String
}

/// Network scan complete
struct NetDoneResponse: Codable {
    let type: String  // "net_done"
    let count: Int
}

// MARK: - Port Scan (Streaming)

/// Open port found during port scan
struct PortResultResponse: Codable {
    let type: String  // "port_result"
    let port: Int
    let service: String
    let banner: String?
}

/// Port scan complete
struct PortDoneResponse: Codable {
    let type: String  // "port_done"
    let count: Int
}

/// Raw port data (preferred)
struct PortRawResponse: Codable {
    let type: String  // "port_raw"
    let ip: String?
    let port: Int
    let `protocol`: String?
    let service: String?
    let banner: String?
    let version: String?
}

/// Open port entry in summary
struct PortSummaryEntry: Codable, Hashable {
    let port: Int
    let portProtocol: String?
    let service: String?
    let banner: String?
    let version: String?
    
    enum CodingKeys: String, CodingKey {
        case port
        case portProtocol = "protocol"
        case service
        case banner
        case version
    }
}

/// Summary for a port scan
struct PortSummaryResponse: Codable {
    let type: String  // "port_summary"
    let target: String?
    let start: Int
    let end: Int
    let os: String?
    let openPorts: [PortSummaryEntry]
}

// MARK: - Progress (Optional)

struct ProgressResponse: Codable {
    let type: String  // "progress"
    let operation: String  // "port_scan", "network_scan", etc.
    let current: Int
    let total: Int
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

// MARK: - ACK

/// Command acknowledgement
struct AckResponse: Codable {
    let type: String  // "ack"
    let cmd: String
}

// MARK: - Cancelled

struct CancelledResponse: Codable {
    let type: String  // "cancelled"
}

// MARK: - Error

struct ErrorResponse: Codable {
    let type: String  // "error"
    let message: String
}

// MARK: - Response Type Enum

enum BLEResponseType: String, Codable {
    case wifiList = "wifi_results"
    case deviceFound = "device"
    case netDone = "net_done"
    case portOpen = "port_result"
    case portDone = "port_done"
    case portRaw = "port_raw"
    case portSummary = "port_summary"
    case progress = "progress"
    case ack = "ack"
    case cancelled = "cancelled"
    case error = "error"
    case status = "status"
    case vulnerability = "vulnerability"
    case analysisComplete = "analysis_complete"
    case wifiScanChunk = "wifi_scan_chunk"
    case wifiScanComplete = "wifi_scan_complete"
    case chunk = "chunk"
    case complete = "complete"
}

// MARK: - Unified Response Parser

/// Unified response that can hold any response type
class BLEResponseParser {
    
    static func parseType(_ jsonString: String) -> BLEResponseType? {
        guard let data = jsonString.data(using: .utf8),
              let base = try? JSONDecoder().decode(BaseResponse.self, from: data) else {
            return nil
        }
        return BLEResponseType(rawValue: base.type)
    }
    
    static func parseWiFiResults(_ jsonString: String) -> WiFiResultsResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WiFiResultsResponse.self, from: data)
    }
    
    static func parseDevice(_ jsonString: String) -> DeviceResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DeviceResponse.self, from: data)
    }
    
    static func parseNetDone(_ jsonString: String) -> NetDoneResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NetDoneResponse.self, from: data)
    }
    
    static func parsePortResult(_ jsonString: String) -> PortResultResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PortResultResponse.self, from: data)
    }
    
    static func parsePortDone(_ jsonString: String) -> PortDoneResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PortDoneResponse.self, from: data)
    }
    
    static func parseProgress(_ jsonString: String) -> ProgressResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ProgressResponse.self, from: data)
    }
    
    static func parseAck(_ jsonString: String) -> AckResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AckResponse.self, from: data)
    }
    
    static func parseCancelled(_ jsonString: String) -> CancelledResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CancelledResponse.self, from: data)
    }
    
    static func parseError(_ jsonString: String) -> ErrorResponse? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ErrorResponse.self, from: data)
    }
}
