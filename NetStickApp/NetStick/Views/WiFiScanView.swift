//
//  WiFiScanView.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//
//  Wi-Fi scanning view
//  Protocol spec: README_PROTOCOL.md

import SwiftUI

/// View for Wi-Fi network scanning and connection
struct WiFiScanView: View {
    @ObservedObject var viewModel: ScannerViewModel
    
    @State private var selectedNetwork: WiFiNetwork?
    @State private var showingPasswordSheet = false
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            DeviceStatusBar(
                status: viewModel.deviceStatus,
                bleConnected: viewModel.bluetoothManager.isConnected
            )
            
            // Content
            if viewModel.isWifiScanning {
                scanningView
            } else if viewModel.wifiNetworks.isEmpty {
                emptyView
            } else {
                networkListView
            }
        }
        .navigationTitle("Wi-Fi Networks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.scanWifi()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isWifiScanning)
            }
        }
        .sheet(isPresented: $showingPasswordSheet) {
            passwordSheet
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.lastError ?? "Unknown error")
        }
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Scanning for Wi-Fi networks...")
                .font(.headline)
            
            if !viewModel.wifiScanProgress.isEmpty {
                Text(viewModel.wifiScanProgress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !viewModel.wifiNetworks.isEmpty {
                Text("\(viewModel.wifiNetworks.count) networks found")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Button("Cancel") {
                viewModel.cancelOperation()
            }
            .foregroundColor(.red)
            .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Networks Found")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Tap the refresh button to scan for available Wi-Fi networks.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                viewModel.scanWifi()
            }) {
                Text("Scan Now")
                    .fontWeight(.semibold)
                    .frame(width: 140)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top)
            
            Spacer()
        }
    }
    
    // MARK: - Network List
    
    private var networkListView: some View {
        List(viewModel.wifiNetworks) { network in
            WiFiNetworkRow(network: network, isConnected: false) {
                selectedNetwork = network
                if network.isSecure {
                    password = ""
                    showingPasswordSheet = true
                } else {
                    viewModel.connectToWifi(ssid: network.ssid, password: "")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Password Sheet
    
    private var passwordSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Network info
                VStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text(selectedNetwork?.ssid ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Secured Network")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Connect button
                Button(action: {
                    if let network = selectedNetwork {
                        viewModel.connectToWifi(ssid: network.ssid, password: password)
                        showingPasswordSheet = false
                    }
                }) {
                    Text("Connect")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Connect to Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingPasswordSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - WiFi Network Row

struct WiFiNetworkRow: View {
    let network: WiFiNetwork
    let isConnected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Wi-Fi icon
                Image(systemName: wifiIconName)
                    .font(.title2)
                    .foregroundColor(isConnected ? .green : .blue)
                    .frame(width: 30)
                
                // Network info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(network.ssid)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isConnected {
                            Text("Connected")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack {
                        if network.isSecure {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                        Text("Ch \(network.channel)")
                        Text("•")
                        Text("\(network.rssi) dBm")
                        Text("•")
                        Text(network.signalDescription)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Signal bars
                SignalBars(level: network.signalLevel)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var wifiIconName: String {
        switch network.signalLevel {
        case 4: return "wifi"
        case 3: return "wifi"
        case 2: return "wifi"
        case 1: return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }
}

// MARK: - Signal Bars

struct SignalBars: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < level ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + index * 3))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WiFiScanView(viewModel: {
            let vm = ScannerViewModel(bluetoothManager: BluetoothManager())
            vm.wifiNetworks = [
                WiFiNetwork(ssid: "Home WiFi", rssi: -45, bssid: "AA:BB:CC:DD:EE:FF", channel: 6, isSecure: true),
                WiFiNetwork(ssid: "Guest Network", rssi: -65, bssid: "11:22:33:44:55:66", channel: 11, isSecure: false),
                WiFiNetwork(ssid: "Neighbor's WiFi", rssi: -78, bssid: "AA:BB:CC:DD:EE:00", channel: 1, isSecure: true)
            ]
            return vm
        }())
    }
}
