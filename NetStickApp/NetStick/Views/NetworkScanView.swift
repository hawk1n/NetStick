//
//  NetworkScanView.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import SwiftUI

/// View for network device scanning
struct NetworkScanView: View {
    @ObservedObject var viewModel: ScannerViewModel
    
    @State private var selectedDevice: NetworkDevice?
    @State private var showingDeviceDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            DeviceStatusBar(
                status: viewModel.deviceStatus,
                bleConnected: viewModel.bluetoothManager.isConnected
            )
            
            // Progress header
            if viewModel.isNetworkScanning {
                progressHeader
            }
            
            // Content
            if viewModel.networkDevices.isEmpty && !viewModel.isNetworkScanning {
                emptyView
            } else {
                deviceGridView
            }
        }
        .navigationTitle("Network Devices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isNetworkScanning {
                    Button("Cancel") {
                        viewModel.cancelOperation()
                    }
                    .foregroundColor(.red)
                } else {
                    Button(action: {
                        viewModel.scanNetwork()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(item: $selectedDevice) { device in
            NavigationStack {
                DeviceDetailView(device: device, viewModel: viewModel)
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.lastError ?? "Unknown error")
        }
    }
    
    // MARK: - Progress Header
    
    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Scanning network...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(viewModel.networkScanProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: viewModel.networkScanProgress)
                .tint(.blue)
            
            Text("\(viewModel.networkDevices.count) devices found")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Devices Found")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Make sure you're connected to a Wi-Fi network and tap Scan to discover devices.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                viewModel.scanNetwork()
            }) {
                Text("Scan Network")
                    .fontWeight(.semibold)
                    .frame(width: 160)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Device Grid
    
    private var deviceGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.networkDevices) { device in
                    DeviceCard(device: device) {
                        selectedDevice = device
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Device Card

struct DeviceCard: View {
    let device: NetworkDevice
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(riskColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: device.deviceType.iconName)
                        .font(.title)
                        .foregroundColor(riskColor)
                }
                
                // IP Address
                Text(device.ip)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Vendor
                Text(device.vendor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Risk badge
                if device.hasOpenPorts || device.hasVulnerabilities {
                    HStack(spacing: 4) {
                        if device.hasOpenPorts {
                            PortCountBadge(count: device.ports.count)
                        }
                        
                        if device.hasVulnerabilities {
                            VulnCountBadge(count: device.vulnerabilities.count, severity: device.maxSeverity)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(riskColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var riskColor: Color {
        switch device.riskLevel {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .none: return .blue
        }
    }
}

// MARK: - Port Count Badge

struct PortCountBadge: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "network")
                .font(.caption2)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(4)
    }
}

// MARK: - Vulnerability Count Badge

struct VulnCountBadge: View {
    let count: Int
    let severity: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(severityColor.opacity(0.2))
        .foregroundColor(severityColor)
        .cornerRadius(4)
    }
    
    private var severityColor: Color {
        switch severity {
        case 9...10: return .red
        case 7...8: return .orange
        case 4...6: return .yellow
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NetworkScanView(viewModel: {
            let vm = ScannerViewModel(bluetoothManager: BluetoothManager())
            vm.networkDevices = [
                NetworkDevice(ip: "192.168.1.1", mac: "AA:BB:CC:DD:EE:FF", vendor: "TP-Link"),
                NetworkDevice(ip: "192.168.1.10", mac: "11:22:33:44:55:66", vendor: "Apple Inc."),
                NetworkDevice(ip: "192.168.1.25", mac: "77:88:99:AA:BB:CC", vendor: "Espressif"),
                NetworkDevice(ip: "192.168.1.100", mac: "DD:EE:FF:00:11:22", vendor: "Intel")
            ]
            return vm
        }())
    }
}
