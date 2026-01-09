//
//  ConnectionView.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import SwiftUI

/// View for BLE device connection
struct ConnectionView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var isConnected: Bool
    
    @State private var showingDisclaimer = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status header
                statusHeader
                
                if !bluetoothManager.isBluetoothEnabled {
                    bluetoothDisabledView
                } else if bluetoothManager.isConnected {
                    connectedView
                } else {
                    deviceListView
                }
            }
            .navigationTitle("NetStick Scanner")
            .navigationBarTitleDisplayMode(.large)
            .alert("Legal Notice", isPresented: $showingDisclaimer) {
                Button("I Understand") {
                    showingDisclaimer = false
                }
            } message: {
                Text("This tool is for authorized network testing only. Unauthorized scanning is illegal and may result in criminal prosecution.")
            }
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        HStack {
            // Bluetooth status
            Label {
                Text(bluetoothManager.isBluetoothEnabled ? "Bluetooth On" : "Bluetooth Off")
            } icon: {
                Image(systemName: bluetoothManager.isBluetoothEnabled ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(bluetoothManager.isBluetoothEnabled ? .blue : .red)
            }
            .font(.caption)
            
            Spacer()
            
            // Connection status
            if bluetoothManager.isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if bluetoothManager.isConnecting {
                Label(bluetoothManager.connectionState.rawValue, systemImage: "circle.dotted")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Bluetooth Disabled
    
    private var bluetoothDisabledView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Bluetooth is Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please enable Bluetooth in Settings to connect to your M5Stick device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let error = bluetoothManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Device List
    
    private var deviceListView: some View {
        VStack(spacing: 16) {
            // Scan button
            Button(action: {
                if bluetoothManager.isScanning {
                    bluetoothManager.stopScanning()
                } else {
                    bluetoothManager.startScanning()
                }
            }) {
                HStack {
                    if bluetoothManager.isScanning {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 4)
                    }
                    
                    Text(bluetoothManager.isScanning ? "Scanning..." : "Scan for Devices")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(bluetoothManager.isScanning ? Color.orange : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Device list
            if bluetoothManager.discoveredPeripherals.isEmpty {
                emptyDeviceListView
            } else {
                List(bluetoothManager.discoveredPeripherals) { device in
                    DeviceRow(device: device) {
                        bluetoothManager.connect(to: device.peripheral)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private var emptyDeviceListView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Devices Found")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Make sure your M5Stick is powered on and in range.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Connected View
    
    private var connectedView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Connected!")
                .font(.title)
                .fontWeight(.bold)
            
            if let name = bluetoothManager.connectedDeviceName {
                Text(name)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Continue button
            Button(action: {
                isConnected = true
            }) {
                Text("Continue to Scanner")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Disconnect button
            Button(action: {
                bluetoothManager.disconnect()
            }) {
                Text("Disconnect")
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: DiscoveredPeripheral
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 12) {
                // Device icon
                Image(systemName: "sensor.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                // Device info
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("RSSI: \(device.rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Signal strength indicator
                SignalStrengthIndicator(strength: device.signalStrength)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Signal Strength Indicator

struct SignalStrengthIndicator: View {
    let strength: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < strength ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(8 + index * 4))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ConnectionView(
        bluetoothManager: BluetoothManager(),
        isConnected: .constant(false)
    )
}
