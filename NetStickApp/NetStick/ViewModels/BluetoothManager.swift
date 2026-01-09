//
//  BluetoothManager.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import Foundation
import CoreBluetooth
import Combine

/// Manages all Bluetooth Low Energy communication with M5Stick device
@MainActor
class BluetoothManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published var connectedDeviceName: String?
    @Published var lastError: String?
    @Published var connectionState: ConnectionState = .disconnected
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?  // Write commands here
    private var txCharacteristic: CBCharacteristic?  // Receive responses here
    
    private var responseBuffer = ""
    private let maxBufferSize = 64000  // Increased for large raw JSON chunks
    private var connectionTimeout: Timer?
    
    // Wi-Fi scan buffering
    private var pendingWiFiChunks: [String: [WiFiChunk]] = [:]
    private var pendingWiFiNetworks: [String: [WiFiNetworkDTO]] = [:]
    
    // Callbacks
    var onResponseReceived: ((BLEResponse) -> Void)?
    var onRawDataReceived: ((String) -> Void)?
    var onAckReceived: ((Ack) -> Void)?
    var onProtoErrorReceived: ((ProtoError) -> Void)?
    var onWiFiChunkReceived: ((WiFiChunk, [WiFiNetworkDTO]) -> Void)?
    var onWiFiScanComplete: ((WiFiComplete, [WiFiNetworkDTO]) -> Void)?
    var onActivity: (() -> Void)?
    
    // MARK: - Init
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        centralManager.delegate = self
    }
    
    // MARK: - Public API
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            lastError = "Bluetooth is not available"
            return
        }
        discoveredPeripherals.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(withServices: [BLEConstants.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.stopScanning() }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        isConnecting = true
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
        connectionTimeout?.invalidate()
        connectionTimeout = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.isConnected { return }
                self.lastError = "Connection timeout - device did not respond"
                if let p = self.connectedPeripheral { self.centralManager.cancelPeripheralConnection(p) }
                self.cleanup()
            }
        }
    }
    
    func disconnect() {
        connectionTimeout?.invalidate()
        if let p = connectedPeripheral { centralManager.cancelPeripheralConnection(p) }
        cleanup()
    }
    
    func sendCommand(_ command: BLECommand) {
        guard isConnected, let peripheral = connectedPeripheral, let rx = rxCharacteristic else {
            lastError = "Not connected to device"
            return
        }
        guard let json = command.toJSON(), let data = json.data(using: .utf8) else {
            lastError = "Failed to encode command"
            return
        }
        if data.count > BLEConstants.maxPayloadSize {
            lastError = "Command too large: \(data.count) bytes"
            return
        }
        print("📤 Sending: \(json)")
        peripheral.writeValue(data, for: rx, type: .withResponse)
    }
    
    func sendRawCommand(_ json: String) {
        guard isConnected, let peripheral = connectedPeripheral, let rx = rxCharacteristic else {
            lastError = "Not connected to device"
            return
        }
        guard let data = json.data(using: .utf8) else {
            lastError = "Failed to encode command"
            return
        }
        if data.count > BLEConstants.maxPayloadSize {
            lastError = "Command too large: \(data.count) bytes"
            return
        }
        print("📤 Sending raw: \(json)")
        peripheral.writeValue(data, for: rx, type: .withResponse)
    }
    
    // MARK: - Private helpers
    private func cleanup() {
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        connectedPeripheral = nil
        rxCharacteristic = nil
        txCharacteristic = nil
        responseBuffer = ""
        isConnected = false
        isConnecting = false
        connectedDeviceName = nil
        connectionState = .disconnected
        pendingWiFiChunks.removeAll()
        pendingWiFiNetworks.removeAll()
    }
    
    private func processReceivedData(_ string: String) {
        responseBuffer += string
        // Log raw BLE fragments
        print("⬇️ RX Fragment (\(string.count) bytes): \(string)")
        onActivity?()
        
        // 1. Try to parse entire buffer as a single JSON message
        if let data = responseBuffer.data(using: .utf8) {
            // Quick check: does it look like JSON?
            let trimmed = responseBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
                if (try? JSONSerialization.jsonObject(with: data)) != nil {
                    parseMessage(responseBuffer)
                    responseBuffer = ""
                    onRawDataReceived?(string)
                    return
                }
            }
        }
        
        // 2. Stream processing: extract complete JSON objects
        tryParseMessages()
        onRawDataReceived?(string)
    }
    
    private func tryParseMessages() {
        // Loop to extract multiple messages if stuck together
        while let range = findCompleteJSON(in: responseBuffer) {
            let json = String(responseBuffer[range])
            
            // Remove the processed part from buffer immediately
            responseBuffer.removeSubrange(range)
            responseBuffer = responseBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse the extracted JSON
            parseMessage(json)
        }
        
        if responseBuffer.count > maxBufferSize {
            print("⚠️ Buffer overflow, clearing")
            responseBuffer = ""
        }
    }
    
    private func findCompleteJSON(in string: String) -> Range<String.Index>? {
        var depth = 0; var inString = false; var escaped = false; var start: String.Index?
        for (i, ch) in string.enumerated() {
            let idx = string.index(string.startIndex, offsetBy: i)
            if escaped { escaped = false; continue }
            if ch == "\\" && inString { escaped = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            if inString { continue }
            if ch == "{" { if depth == 0 { start = idx }; depth += 1 }
            else if ch == "}" { depth -= 1; if depth == 0, let s = start { return s..<string.index(after: idx) } }
        }
        return nil
    }
    
    private func parseMessage(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = dict["type"] as? String {
            switch type {
            case "ack":
                if let ack = try? decoder.decode(Ack.self, from: data) { handleAck(ack) } else { print("⚠️ Failed to decode ACK: \(json.prefix(200))...") }
            case "error":
                if let err = try? decoder.decode(ProtoError.self, from: data) { handleProtoError(err) } else { print("⚠️ Failed to decode error: \(json.prefix(200))...") }
            case "wifi_scan_chunk", "chunk":
                if let chunk = try? decoder.decode(WiFiChunk.self, from: data), chunk.isWiFi { handleWiFiChunk(chunk) } else { print("⚠️ Failed to decode Wi-Fi chunk: \(json.prefix(200))...") }
            case "wifi_scan_complete", "complete":
                if let complete = try? decoder.decode(WiFiComplete.self, from: data), complete.isWiFi { handleWiFiComplete(complete) } else { print("⚠️ Failed to decode Wi-Fi complete: \(json.prefix(200))...") }
            default:
                if let resp = try? decoder.decode(BLEResponse.self, from: data) { onResponseReceived?(resp) }
                else { print("⚠️ Unknown or undecodable JSON: \(json.prefix(200))...") }
            }
        } else {
            print("⚠️ JSON without type or parse failure: \(json.prefix(200))...")
        }
    }
    
    // MARK: - Handlers
    private func handleAck(_ ack: Ack) {
        print("✅ ACK received for \(ack.cmd ?? ack.action ?? "unknown"): \(ack.status)")
        if ack.status == "error" { lastError = ack.message ?? "Command failed" }
        onAckReceived?(ack)
        let resp = BLEResponse(type: "ack", message: ack.message, code: nil, details: nil, status: ack.status, ble: nil, wifi: nil, ip: nil, battery: nil, stage: nil, percent: nil, networks: nil, mac: nil, vendor: nil, count: nil, port: nil, service: nil, banner: nil, cve: nil, severity: nil, description: nil, vulns: nil, maxSeverity: nil, cmd: ack.cmd ?? ack.action, requestId: ack.effectiveRequestId, timestamp: ack.timestamp, domain: ack.domain, action: ack.action, id: ack.id)
        onResponseReceived?(resp)
    }
    
    private func handleProtoError(_ error: ProtoError) {
        print("❌ Protocol error: \(error.code ?? 0) - \(error.message)")
        lastError = error.message
        onProtoErrorReceived?(error)
        let resp = BLEResponse(type: "error", message: error.message, code: error.code, details: error.details, status: nil, ble: nil, wifi: nil, ip: nil, battery: nil, stage: nil, percent: nil, networks: nil, mac: nil, vendor: nil, count: nil, port: nil, service: nil, banner: nil, cve: nil, severity: nil, description: nil, vulns: nil, maxSeverity: nil, cmd: nil, requestId: error.effectiveRequestId, timestamp: nil, domain: error.domain, action: nil, id: error.id)
        onResponseReceived?(resp)
    }
    
    private func handleWiFiChunk(_ chunk: WiFiChunk) {
        guard chunk.isWiFi else { return }
        guard let reqId = chunk.effectiveRequestId else { print("⚠️ Wi-Fi chunk without requestId"); return }
        print("📦 Wi-Fi chunk \(chunk.seq + 1)/\(chunk.total) for request \(reqId.prefix(8))...")
        var networks: [WiFiNetworkDTO] = []
        switch chunk.payload {
        case .networks(let nets):
            networks = nets
        case .encoded(let base64):
            guard let crc = chunk.crc else { print("⚠️ Encoded payload without CRC"); return }
            guard let decoded = Data(base64Encoded: base64), let json = String(data: decoded, encoding: .utf8) else { print("⚠️ Failed to decode base64 payload"); return }
            let crcCalc = crc32String(json)
            if crcCalc.uppercased() != crc.uppercased() { print("⚠️ CRC mismatch: expected \(crc), got \(crcCalc)") }
            guard let d = json.data(using: .utf8), let nets = try? JSONDecoder().decode([WiFiNetworkDTO].self, from: d) else { print("⚠️ Failed to parse networks from decoded payload"); return }
            networks = nets
        }
        var list = pendingWiFiNetworks[reqId] ?? []
        list.append(contentsOf: networks)
        pendingWiFiNetworks[reqId] = list
        pendingWiFiChunks[reqId, default: []].append(chunk)
        onWiFiChunkReceived?(chunk, list)
    }
    
    private func handleWiFiComplete(_ complete: WiFiComplete) {
        guard complete.isWiFi else { return }
        guard let reqId = complete.effectiveRequestId else { print("⚠️ Wi-Fi complete without requestId"); return }
        print("✅ Wi-Fi scan complete: \(complete.count) networks")
        let nets = pendingWiFiNetworks[reqId] ?? []
        pendingWiFiNetworks.removeValue(forKey: reqId)
        pendingWiFiChunks.removeValue(forKey: reqId)
        onWiFiScanComplete?(complete, nets)
    }
    
    private func crc32String(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "00000000" }
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xEDB88320 : 0) }
        }
        crc ^= 0xFFFFFFFF
        return String(format: "%08X", crc)
    }
    
    func clearPendingData(for requestId: String) {
        pendingWiFiChunks.removeValue(forKey: requestId)
        pendingWiFiNetworks.removeValue(forKey: requestId)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn: isBluetoothEnabled = true; lastError = nil
            case .poweredOff: isBluetoothEnabled = false; lastError = "Bluetooth is turned off"
            case .unauthorized: isBluetoothEnabled = false; lastError = "Bluetooth access not authorized"
            case .unsupported: isBluetoothEnabled = false; lastError = "Bluetooth is not supported"
            default: isBluetoothEnabled = false
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
            let discovered = DiscoveredPeripheral(peripheral: peripheral, name: name, rssi: RSSI.intValue)
            if !discoveredPeripherals.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(discovered)
                print("🔍 Discovered: \(name) (RSSI: \(RSSI))")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("✅ Connected to: \(peripheral.name ?? "Unknown")")
            connectedDeviceName = peripheral.name
            connectionState = .discoveringServices
            peripheral.discoverServices(nil)
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            lastError = error?.localizedDescription ?? "Connection failed"
            print("❌ Failed to connect: \(lastError ?? "")")
            cleanup()
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if let e = error { lastError = e.localizedDescription }
            print("🔌 Disconnected from: \(peripheral.name ?? "Unknown")")
            cleanup()
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error { lastError = error.localizedDescription; print("❌ Service discovery error: \(error.localizedDescription)"); connectionTimeout?.invalidate(); return }
            guard let services = peripheral.services, !services.isEmpty else {
                lastError = "No services found on device"; print("⚠️ No services found"); connectionTimeout?.invalidate(); cleanup(); return }
            print("🔍 Found \(services.count) service(s)")
            for service in services {
                print("   Service UUID: \(service.uuid)")
                if service.uuid == BLEConstants.serviceUUID {
                    connectionState = .discoveringCharacteristics
                    peripheral.discoverCharacteristics(nil, for: service)
                    return
                }
            }
            lastError = "Expected BLE service not found"; print("⚠️ Nordic UART Service not found"); connectionTimeout?.invalidate(); cleanup()
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error { lastError = error.localizedDescription; print("❌ Characteristic discovery error: \(error.localizedDescription)"); connectionTimeout?.invalidate(); cleanup(); return }
            guard let characteristics = service.characteristics, !characteristics.isEmpty else {
                lastError = "No characteristics found"; print("⚠️ No characteristics found"); connectionTimeout?.invalidate(); cleanup(); return }
            print("🔍 Found \(characteristics.count) characteristic(s):")
            for characteristic in characteristics {
                print("   Characteristic UUID: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties)")
                if characteristic.uuid == BLEConstants.rxUUID {
                    rxCharacteristic = characteristic; print("   ✅ This is RX (write)")
                }
                if characteristic.uuid == BLEConstants.txUUID {
                    txCharacteristic = characteristic; print("   ✅ This is TX (notify)"); peripheral.setNotifyValue(true, for: characteristic)
                }
                // Fallback: some firmware exposes single characteristic on service UUID
                if characteristic.uuid == BLEConstants.serviceUUID {
                    if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                        if rxCharacteristic == nil { rxCharacteristic = characteristic; print("   ⚙️ Using service UUID characteristic as RX") }
                    }
                    if characteristic.properties.contains(.notify) {
                        if txCharacteristic == nil { txCharacteristic = characteristic; print("   ⚙️ Using service UUID characteristic as TX (notify)") }
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
            if rxCharacteristic != nil && txCharacteristic != nil {
                print("🎉 Both characteristics available - waiting for notification setup...")
            } else {
                if rxCharacteristic == nil { print("   ❌ RX characteristic not found") }
                if txCharacteristic == nil { print("   ❌ TX characteristic not found") }
                lastError = "Required BLE characteristics not found"
                connectionTimeout?.invalidate()
                cleanup()
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error { print("❌ Update value error: \(error.localizedDescription)"); return }
            guard (characteristic.uuid == BLEConstants.txUUID || characteristic.uuid == BLEConstants.serviceUUID),
                  let data = characteristic.value,
                  let string = String(data: data, encoding: .utf8) else { return }
            processReceivedData(string)
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error { lastError = error.localizedDescription; print("❌ Write error: \(error.localizedDescription)") }
            else { print("✅ Command sent successfully") }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error { lastError = error.localizedDescription; print("❌ Notification state error: \(error.localizedDescription)"); connectionTimeout?.invalidate(); cleanup(); return }
            if (characteristic.uuid == BLEConstants.txUUID || characteristic.uuid == BLEConstants.serviceUUID) && characteristic.isNotifying {
                print("✅ Notifications enabled")
                if rxCharacteristic != nil && txCharacteristic != nil {
                    connectionTimeout?.invalidate()
                    isConnected = true
                    isConnecting = false
                    connectionState = .connected
                    print("🎉 Ready to communicate!")
                }
            }
        }
    }
}

// MARK: - Supporting Types
struct DiscoveredPeripheral: Identifiable {
    let id = UUID()
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int
    var signalStrength: Int { switch rssi { case -50...0: return 4; case -60...(-50): return 3; case -70...(-60): return 2; case -80...(-70): return 1; default: return 0 } }
}

enum ConnectionState: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case discoveringServices = "Discovering Services..."
    case discoveringCharacteristics = "Discovering Characteristics..."
    case connected = "Connected"
}
