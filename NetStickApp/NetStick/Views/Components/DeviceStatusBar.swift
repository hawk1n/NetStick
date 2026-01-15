//
//  DeviceStatusBar.swift
//  NetStick
//
//  Device status bar component displaying battery, charging, and WiFi state
//

import SwiftUI

struct DeviceStatusBar: View {
    let status: DeviceStatus?
    let bleConnected: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            let bt = status?.btConnected ?? bleConnected
            statusChip(icon: bt ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash",
                       text: bt ? "BLE Connected" : "BLE Disconnected",
                       color: bt ? .blue : .gray)
            
            if let status {
                statusChip(icon: status.charging ? "bolt.fill" : status.batteryLevel.iconName,
                           text: "\(status.battery)% Battery",
                           color: batteryColor(status.batteryLevel))
                
                statusChip(icon: status.isConnectedToWiFi ? "wifi" : "wifi.slash",
                           text: status.isConnectedToWiFi ? (status.ssid ?? status.wifi) : "No WiFi",
                           color: status.isConnectedToWiFi ? .green : .gray,
                           footer: status.rssi.map { "\($0) dBm • \(status.signalDescription)" })
                
                statusChip(icon: "gauge",
                           text: status.activeStageDescription,
                           color: .orange,
                           footer: status.percent.map { "\($0)%"} ?? nil)
<<<<<<< HEAD
=======
                
                statusChip(icon: "clock",
                           text: "Uptime \(status.uptimeDescription)",
                           color: .purple)
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
            } else {
                statusChip(icon: "hourglass", text: "Awaiting status", color: .gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func batteryColor(_ level: BatteryLevel) -> Color {
        switch level {
        case .low: return .red
        case .medium: return .orange
        case .good: return .yellow
        case .full: return .green
        }
    }
    
    @ViewBuilder
    private func statusChip(icon: String, text: String, color: Color, footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(text)
                    .font(.caption2)
                    .lineLimit(1)
            }
            if let footer {
                Text(footer)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        DeviceStatusBar(
<<<<<<< HEAD
            status: DeviceStatus(battery: 85, charging: false, wifi: "MyNetwork", rssi: -55, stage: "network_scan", percent: 42),
=======
            status: DeviceStatus(battery: 85, charging: false, wifi: "MyNetwork", rssi: -55, stage: "network_scan", percent: 42, uptime: 7260),
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
            bleConnected: true
        )
        
        DeviceStatusBar(
<<<<<<< HEAD
            status: DeviceStatus(battery: 15, charging: true, wifi: "disconnected", rssi: nil, stage: "idle", percent: 0),
=======
            status: DeviceStatus(battery: 15, charging: true, wifi: "disconnected", rssi: nil, stage: "idle", percent: 0, uptime: 180),
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
            bleConnected: true
        )
        
        DeviceStatusBar(
            status: nil,
            bleConnected: false
        )
    }
}
