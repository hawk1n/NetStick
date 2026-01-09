//
//  DeviceDetailView.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//
//  Device detail view
//  Protocol spec: README_PROTOCOL.md

import SwiftUI

/// Detailed view for a network device
struct DeviceDetailView: View {
    let device: NetworkDevice
    @ObservedObject var viewModel: ScannerViewModel
    
    @State private var portsRange = "1-1024"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            DeviceStatusBar(
                status: viewModel.deviceStatus,
                bleConnected: viewModel.bluetoothManager.isConnected
            )
            
            ScrollView {
                VStack(spacing: 20) {
                    // Device header
                    deviceHeader
                    
                    // Device info
                    deviceInfoSection
                    
                    // Port scan section
                    portScanSection
                    
                    // Open ports
                    if !liveDevice.ports.isEmpty {
                        openPortsSection
                    }
                    
                    // Vulnerabilities
                    if !liveDevice.vulnerabilities.isEmpty {
                        vulnerabilitiesSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Device Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Device Header
    
    private var deviceHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(riskColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: device.deviceType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(riskColor)
            }
            
            Text(liveDevice.ip)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(liveDevice.vendor)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Risk badge
            Text(liveDevice.riskLevel.description)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(riskColor.opacity(0.2))
                .foregroundColor(riskColor)
                .cornerRadius(8)
        }
    }
    
    // MARK: - Device Info Section
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Device Information")
            
            VStack(spacing: 12) {
                InfoRow(label: "IP Address", value: liveDevice.ip, icon: "network")
                InfoRow(label: "MAC Address", value: liveDevice.mac, icon: "barcode")
                InfoRow(label: "Vendor", value: liveDevice.vendor, icon: "building.2")
                InfoRow(label: "Open Ports", value: "\(liveDevice.ports.count)", icon: "door.left.hand.open")
                InfoRow(label: "Vulnerabilities", value: "\(liveDevice.vulnerabilities.count)", icon: "exclamationmark.shield")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Port Scan Section
    
    private var portScanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Port Scan")
            
            VStack(spacing: 12) {
                // Port range input
                HStack {
                    Text("Ports:")
                        .font(.subheadline)
                    
                    TextField("1-1024", text: $portsRange)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                }
                
                // Progress
                if viewModel.isPortScanning {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.portScanProgress)
                            .tint(.blue)
                        
                        Text("Scanning... \(Int(viewModel.portScanProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Quick Scan button
                Button(action: {
                    if viewModel.isPortScanning {
                        viewModel.cancelOperation()
                    } else {
                        // Parse port range (e.g. "1-1024")
                        let parts = portsRange.split(separator: "-")
                        let startPort = Int(parts.first ?? "1") ?? 1
                        let endPort = Int(parts.last ?? "1024") ?? 1024
                        viewModel.scanPorts(ip: device.ip, startPort: startPort, endPort: endPort)
                    }
                }) {
                    HStack {
                if viewModel.isPortScanning {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 4)
                }
                        
                        Text(viewModel.isPortScanning ? "Cancel Scan" : "Quick Scan")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isPortScanning ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Advanced Scan button
                Button(action: {
                    viewModel.scanTopPorts(ip: device.ip)
                }) {
                    HStack {
                        Image(systemName: "list.number")
                        Text("Scan 1000")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isPortScanning)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Open Ports Section
    
    private var openPortsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Open Ports (\(liveDevice.ports.count))")
            
            VStack(spacing: 8) {
                ForEach(liveDevice.ports.sorted { $0.number < $1.number }) { port in
                    PortRow(port: port)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Vulnerabilities Section
    
    private var vulnerabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Vulnerabilities (\(liveDevice.vulnerabilities.count))")
            
            VStack(spacing: 8) {
                ForEach(liveDevice.vulnerabilities) { vuln in
                    VulnerabilityRow(vulnerability: vuln)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helpers
    
    private var riskColor: Color {
        switch liveDevice.riskLevel {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .none: return .blue
        }
    }
    
    private var liveDevice: NetworkDevice {
        viewModel.networkDevices.first(where: { $0.ip == device.ip }) ?? device
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Port Row

struct PortRow: View {
    let port: OpenPort
    
    var body: some View {
        HStack {
            // Port number badge
            Text("\(port.number)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
            
            // Service name
            Text(port.service)
                .font(.subheadline)
            
            Spacer()
            
            // Risk indicator
            Circle()
                .fill(port.color)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
        
        if let banner = port.banner, !banner.isEmpty {
            Text(banner)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.leading, 60)
        }
    }
}

// MARK: - Vulnerability Row

struct VulnerabilityRow: View {
    let vulnerability: Vulnerability
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vulnerability.cve)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Severity badge
                Text(vulnerability.severityLevel.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vulnerability.color.opacity(0.2))
                    .foregroundColor(vulnerability.color)
                    .cornerRadius(4)
            }
            
            Text(vulnerability.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DeviceDetailView(
            device: {
                var device = NetworkDevice(ip: "192.168.1.1", mac: "AA:BB:CC:DD:EE:FF", vendor: "TP-Link")
                device.ports = [
                    OpenPort(number: 22, service: "SSH", banner: "SSH-2.0-OpenSSH"),
                    OpenPort(number: 80, service: "HTTP", banner: nil),
                    OpenPort(number: 443, service: "HTTPS", banner: nil)
                ]
                device.vulnerabilities = [
                    Vulnerability(cve: "CVE-2021-41773", severity: 9, description: "Path traversal vulnerability")
                ]
                return device
            }(),
            viewModel: ScannerViewModel(bluetoothManager: BluetoothManager())
        )
    }
}
