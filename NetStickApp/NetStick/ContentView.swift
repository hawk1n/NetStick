//  ContentView.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import SwiftUI

/// Main content view - root of the app navigation
struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var scannerViewModel: ScannerViewModel
    
    @State private var isConnected = false
    @State private var selectedTab = 0
    
    init() {
        let btManager = BluetoothManager()
        _bluetoothManager = StateObject(wrappedValue: btManager)
        _scannerViewModel = StateObject(wrappedValue: ScannerViewModel(bluetoothManager: btManager))
    }
    
    var body: some View {
        Group {
            if !isConnected {
                ConnectionView(bluetoothManager: bluetoothManager, isConnected: $isConnected)
            } else {
                mainTabView
            }
        }
        .onChange(of: bluetoothManager.isConnected) { _, newValue in
            isConnected = newValue
            if newValue {
                scannerViewModel.getStatus()
            }
        }
    }
    
    // MARK: - Main Tab View
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WiFiScanView(viewModel: scannerViewModel)
            }
            .tabItem { Label("Wi-Fi", systemImage: "wifi") }
            .tag(0)
            
            NavigationStack {
                NetworkScanView(viewModel: scannerViewModel)
            }
            .tabItem { Label("Network", systemImage: "network") }
            .tag(1)
            
            NavigationStack {
                StatusView(bluetoothManager: bluetoothManager, viewModel: scannerViewModel)
            }
            .tabItem { Label("Status", systemImage: "info.circle") }
            .tag(2)
        }
    }
}

// MARK: - Status View

struct StatusView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var viewModel: ScannerViewModel
    
    var body: some View {
        List {
            Section("Connection") {
                HStack {
                    Label("BLE Status", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    Text(bluetoothManager.connectionState.rawValue)
                        .foregroundColor(.secondary)
                }
                if let name = bluetoothManager.connectedDeviceName {
                    HStack {
                        Label("Device", systemImage: "sensor.fill")
                        Spacer()
                        Text(name).foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Scan Results") {
                HStack {
                    Label("Wi-Fi Networks", systemImage: "wifi"); Spacer()
                    Text("\(viewModel.wifiNetworks.count)").foregroundColor(.secondary)
                }
                HStack {
                    Label("Network Devices", systemImage: "desktopcomputer"); Spacer()
                    Text("\(viewModel.networkDevices.count)").foregroundColor(.secondary)
                }
                let totalPorts = viewModel.networkDevices.reduce(0) { $0 + $1.ports.count }
                HStack {
                    Label("Open Ports", systemImage: "door.left.hand.open"); Spacer()
                    Text("\(totalPorts)").foregroundColor(.secondary)
                }
                let totalVulns = viewModel.networkDevices.reduce(0) { $0 + $1.vulnerabilities.count }
                HStack {
                    Label("Vulnerabilities", systemImage: "exclamationmark.triangle"); Spacer()
                    Text("\(totalVulns)").foregroundColor(totalVulns > 0 ? .red : .secondary)
                }
            }
            
            Section("Actions") {
                Button(role: .destructive) { bluetoothManager.disconnect() } label: {
                    Label("Disconnect", systemImage: "wifi.slash")
                }
            }
        }
        .navigationTitle("Status")
    }
}

#Preview {
    ContentView()
}
