//
//  ScannerViewModel.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import Foundation
import Combine

/// Main ViewModel for scanner business logic
@MainActor
class ScannerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Wi-Fi
    @Published var wifiNetworks: [WiFiNetwork] = []
    @Published var isWifiScanning = false
    @Published var connectedSSID: String?
    @Published var wifiScanProgress: String = ""  // Progress text
    
    // Network devices
    @Published var networkDevices: [NetworkDevice] = []
    @Published var isNetworkScanning = false
    @Published var networkScanProgress: Double = 0
    
    // Port scan
    @Published var isPortScanning = false
    @Published var portScanProgress: Double = 0
    @Published var selectedDevice: NetworkDevice?
    
    // Analysis
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    
    // Status
    @Published var deviceStatus: DeviceStatus?
    @Published var lastError: String?
    @Published var showingError = false
    
    // MARK: - Dependencies
    
    let bluetoothManager: BluetoothManager
    
    // MARK: - Private Properties
    
    private var tempDevices: [NetworkDevice] = []
    private var tempPorts: [String: [OpenPort]] = [:]  // IP -> ports
    private var tempVulnerabilities: [String: [Vulnerability]] = [:]  // IP -> vulns
    private var currentPortTarget: String?
    
    private var scanTimeout: Timer?
    private var ackTimeout: Timer?
    private var chunkTimeout: Timer?
    private var inactivityTimer: Timer?
    private var lastPacketAt: Date?
    
    private enum OperationKind {
        case wifi, network, port, advanced, analysis
    }
    private var activeOperation: OperationKind?
    
    // Current WiFi scan request tracking
    private var currentWiFiRequestId: String?
    private var receivedChunks: Set<Int> = []
    private var expectedTotalChunks: Int = 0
    
    // MARK: - Initialization
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        setupResponseHandler()
        bluetoothManager.onActivity = { [weak self] in
            self?.refreshInactivityTimer()
        }
    }
    
    // MARK: - Public Methods
    
    /// Scan for Wi-Fi networks
    func scanWifi(duration: Int? = nil, mode: String? = nil, channels: [Int]? = nil) {
        guard bluetoothManager.isConnected else {
            showError("Not connected to device")
            return
        }
        guard !isWifiScanning else {
            showError("Wi-Fi scan already in progress")
            return
        }
        
        // Generate request ID
        let requestId = BLECommand.generateRequestId()
        currentWiFiRequestId = requestId
        receivedChunks.removeAll()
        expectedTotalChunks = 0
        
        wifiNetworks.removeAll()
        isWifiScanning = true
        wifiScanProgress = "Starting scan..."
        beginOperation(.wifi)
        
        // Create params
        var params: WiFiScanParams? = nil
        if duration != nil || mode != nil || channels != nil {
            params = WiFiScanParams(duration: duration, mode: mode, channels: channels)
        }
        
        bluetoothManager.sendCommand(.wifiScan(requestId: requestId, params: params))
        
        // ACK timeout (5 seconds)
        startAckTimeout(5) { [weak self] in
            guard let self = self else { return }
            if self.currentWiFiRequestId == requestId {
                self.isWifiScanning = false
                self.showError("No ACK received from device")
            }
        }
    }

    /// Connect to a Wi-Fi network
    func connectToWifi(ssid: String, password: String) {
        guard bluetoothManager.isConnected else {
            showError("Not connected to device")
            return
        }
        
        bluetoothManager.sendCommand(.connect(ssid: ssid, password: password))
    }
    
    /// Scan local network for devices
    func scanNetwork() {
        guard bluetoothManager.isConnected else {
            showError("Not connected to device")
            return
        }
        
        tempDevices.removeAll()
        networkDevices.removeAll()
        networkScanProgress = 0
        isNetworkScanning = true
        beginOperation(.network)
        
        bluetoothManager.sendCommand(.networkScan)
    }
    
    /// Scan ports on a device (Range)
    func scanPorts(ip: String, startPort: Int, endPort: Int) {
        guard bluetoothManager.isConnected else {
            showError("Not connected to device")
            return
        }
        
        tempPorts[ip] = []
        portScanProgress = 0
        isPortScanning = true
        beginOperation(.port)
        currentPortTarget = ip
        
        bluetoothManager.sendCommand(.scanPorts(ip: ip, startPort: startPort, endPort: endPort))
    }

    /// Scan ports on a device (String/Legacy)
    func scanPorts(ip: String, ports: String? = nil) {
        if let p = ports, !p.isEmpty {
            // Parse comma-separated port list and find range
            let portList = p.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if let minPort = portList.min(), let maxPort = portList.max() {
                scanPorts(ip: ip, startPort: minPort, endPort: maxPort)
            } else {
                scanPorts(ip: ip, startPort: 20, endPort: 1000)
            }
        } else {
            // Default: common ports (use range that covers them)
            scanPorts(ip: ip, startPort: 20, endPort: 8443)
        }
    }
    
    /// Top 1000 TCP ports scan
    func scanTopPorts(ip: String) {
        scanPorts(ip: ip, startPort: 1, endPort: 1000)
    }
    
    /// Analyze device for vulnerabilities
    func analyzeDevice(ip: String) {
        guard bluetoothManager.isConnected else {
            showError("Not connected to device")
            return
        }
        
        tempVulnerabilities[ip] = []
        analysisProgress = 0
        isAnalyzing = true
        isPortScanning = true
        portScanProgress = 0
        beginOperation(.analysis)
        currentPortTarget = ip
        
        bluetoothManager.sendCommand(.analyze(ip: ip))
    }
    
    /// Advanced scan (nmap-style) on a device
    func advancedScan(ip: String, osDetect: Bool = false, serviceVersion: Bool = true) {
        guard bluetoothManager.isConnected else {
            showError("Not connected to device")
            return
        }
        
        tempPorts[ip] = []
        portScanProgress = 0
        isPortScanning = true
        beginOperation(.advanced)
        currentPortTarget = ip
        
        bluetoothManager.sendCommand(.advancedScan(ip: ip, osDetect: osDetect, serviceVersion: serviceVersion))
    }
    
    /// Get device status
    func getStatus() {
        guard bluetoothManager.isConnected else {
            showError("Not connected to device")
            return
        }
        
        bluetoothManager.sendCommand(.status)
    }
    
    /// Cancel current operation
    func cancelOperation() {
        bluetoothManager.sendCommand(.cancel)
        cancelAllTimeouts()
        stopAllScans()
    }
    
    /// Check if any operation is in progress
    var isOperationInProgress: Bool {
        isWifiScanning || isNetworkScanning || isPortScanning || isAnalyzing
    }
    
    // MARK: - Private Methods
    
    private func setupResponseHandler() {
        bluetoothManager.onResponseReceived = { [weak self] response in
            self?.handleResponse(response)
        }
        
        bluetoothManager.onAckReceived = { ack in
            print("✅ Command acknowledged: \(ack.cmd)")
        }

        bluetoothManager.onProtoErrorReceived = { [weak self] error in
            self?.handleProtoError(error)
        }
        
        bluetoothManager.onWiFiChunkReceived = { [weak self] chunk, networks in
            self?.handleWiFiChunk(chunk, networks: networks)
        }
        
        bluetoothManager.onWiFiScanComplete = { [weak self] complete, networks in
            self?.handleWiFiScanComplete(complete, networks: networks)
        }
    }
    
    // MARK: - New Protocol Handlers
    
    private func handleAck(_ ack: Ack) {
        cancelAckTimeout()
        
        if ack.cmd == "start_wifi_scan" {
            if ack.status == "ok" {
                wifiScanProgress = "Scanning..."
            } else {
                isWifiScanning = false
                currentWiFiRequestId = nil
                showError(ack.message ?? "Scan failed")
            }
        }
    }
    
    private func handleProtoError(_ error: ProtoError) {
        cancelAllTimeouts()
        endOperation()
        
        // Check if this error is for current WiFi scan
        if let requestId = error.requestId, requestId == currentWiFiRequestId {
            isWifiScanning = false
            currentWiFiRequestId = nil
        }
        
        showError(error.message)
    }
    
    private func handleWiFiChunk(_ chunk: WiFiChunk, networks: [WiFiNetworkDTO]) {
        // Verify this is for current scan
        guard chunk.requestId == currentWiFiRequestId else { return }
        refreshInactivityTimer()

        print("📥 Wi-Fi chunk handled seq=\(chunk.seq) total=\(chunk.total) req=\(chunk.requestId)")

        // Cancel ACK and overall timeouts once data starts arriving
        cancelAckTimeout()
        cancelTimeout()

        // Restart chunk timeout
        restartChunkTimeout()

        // Track received chunks
        receivedChunks.insert(chunk.seq)
        expectedTotalChunks = chunk.total
        
        // Update progress
        wifiScanProgress = "Receiving data \(chunk.seq + 1)/\(chunk.total)..."
        
        // Update networks in real-time
        wifiNetworks = networks.map { WiFiNetwork(from: $0) }
            .sorted { $0.rssi > $1.rssi }
    }
    
    private func handleWiFiScanComplete(_ complete: WiFiComplete, networks: [WiFiNetworkDTO]) {
        // Ensure this completion is for the current scan
        guard complete.requestId == currentWiFiRequestId else { return }
        refreshInactivityTimer()

        print("📥 Wi-Fi complete handled req=\(complete.requestId ?? "nil") count=\(complete.count)")

        cancelAllTimeouts()
        cancelAckTimeout()
        endOperation()

        isWifiScanning = false
        currentWiFiRequestId = nil
        wifiScanProgress = ""
        
        // Final update of networks
        wifiNetworks = networks.map { WiFiNetwork(from: $0) }
            .sorted { $0.rssi > $1.rssi }
        
        print("✅ Wi-Fi scan complete: \(wifiNetworks.count) networks")
    }
    
    private func handleResponse(_ response: BLEResponse) {
        refreshInactivityTimer()
        switch response.responseType {
        case .error:
            cancelAllTimeouts()
            stopAllScans()
            showError(response.message ?? "Unknown error")
            
        case .status:
            handleStatus(response)
            
        case .progress:
            handleProgress(response)
            
        case .wifiList:
            // Legacy handler
            cancelTimeout()
            handleWifiList(response)
            
        case .deviceFound:
            handleDeviceFound(response)
            
        case .netDone:
            cancelTimeout()
            handleNetDone(response)
            
        case .portOpen:
            handlePortOpen(response)
            
        case .portRaw:
            handlePortRaw(response)
            
        case .portDone:
            cancelTimeout()
            handlePortDone(response)
            
        case .portSummary:
            handlePortSummary(response)
            
        case .vulnerability:
            handleVulnerability(response)
            
        case .analysisComplete:
            handleAnalysisComplete(response)
            
        case .cancelled:
            cancelAllTimeouts()
            stopAllScans()
            
        case .ack:
            print("✅ Command acknowledged: \(response.cmd ?? "unknown")")
            cancelAckTimeout()
            
        case .wifiScanChunk, .wifiScanComplete, .chunk, .complete:
            // Handled by dedicated callbacks
            break
            
        case .none:
            print("⚠️ Unknown response type: \(response.type)")
        }
    }
    
    private func handleStatus(_ response: BLEResponse) {
        let reportedWifi = response.ssid ?? response.wifi ?? "disconnected"
        if response.wifiConnected == true {
            connectedSSID = reportedWifi
        } else if response.wifiConnected == false {
            connectedSSID = nil
        } else if reportedWifi != "disconnected" && reportedWifi != "unknown" {
            connectedSSID = reportedWifi
        }
        
        // Update device status
        if let battery = response.battery {
            deviceStatus = DeviceStatus(
                battery: battery,
                charging: response.charging ?? false,
                wifi: reportedWifi,
                rssi: response.rssi,
                stage: response.operation ?? response.stage,
                percent: response.progress ?? response.percent,
                btConnected: response.btConnected,
                wifiConnected: response.wifiConnected,
                ssid: response.ssid ?? response.wifi
            )
        }
    }
    
    private func handleProgress(_ response: BLEResponse) {
        let stage = response.stage ?? response.operation ?? ""
        let progress: Double
        if let current = response.current, let total = response.total, total > 0 {
            progress = Double(current) / Double(total)
        } else {
            progress = Double(response.percent ?? 0) / 100.0
        }
        
        if var status = deviceStatus {
            deviceStatus = DeviceStatus(
                battery: status.battery,
                charging: status.charging,
                wifi: status.wifi,
                rssi: status.rssi,
                stage: stage,
                percent: Int(progress * 100)
            )
        }
        
        switch stage {
        case "network_scan":
            if activeOperation == nil { beginOperation(.network) }
            networkScanProgress = progress
            isNetworkScanning = true
        case "port_scan":
            if activeOperation == nil { beginOperation(.port) }
            portScanProgress = progress
            isPortScanning = true
        case "advanced_scan":
            if activeOperation == nil { beginOperation(.advanced) }
            portScanProgress = progress
            isPortScanning = true
        case "analysis":
            if activeOperation == nil { beginOperation(.analysis) }
            analysisProgress = progress
            isAnalyzing = true
        case "wifi_scan":
            if activeOperation == nil { beginOperation(.wifi) }
            isWifiScanning = true
            wifiScanProgress = "Scanning... \(Int(progress * 100))%"
        default:
            break
        }
    }
    
    private func handleWifiList(_ response: BLEResponse) {
        isWifiScanning = false
        endOperation()
        
        if let networks = response.networks {
            wifiNetworks = networks.map { WiFiNetwork(from: $0) }
                .sorted { $0.rssi > $1.rssi }  // Sort by signal strength
        }
    }
    
    private func handleDeviceFound(_ response: BLEResponse) {
        guard let ip = response.ip,
              let mac = response.mac else { return }
        
        let device = NetworkDevice(
            ip: ip,
            mac: mac,
            vendor: response.vendor ?? "Unknown"
        )
        
        // Avoid duplicates
        if !tempDevices.contains(where: { $0.ip == ip }) {
            tempDevices.append(device)
            // Update UI in real-time
            networkDevices = tempDevices
        }
    }
    
    private func handleNetDone(_ response: BLEResponse) {
        isNetworkScanning = false
        networkScanProgress = 1.0
        networkDevices = tempDevices
        print("✅ Network scan complete: \(response.count ?? tempDevices.count) devices")
        endOperation()
    }
    
    private func handlePortOpen(_ response: BLEResponse) {
        guard let portNumber = response.port else { return }
        let ip = response.ip ?? currentPortTarget ?? selectedDevice?.ip
        guard let ip else { return }
        
        let port = OpenPort(
            number: portNumber,
            service: response.service ?? "Unknown",
            banner: response.banner
        )
        
        storeOpenPort(ip: ip, port: port)
    }
    
    private func handlePortDone(_ response: BLEResponse) {
        isPortScanning = false
        portScanProgress = 1.0
        
        let ip = response.ip ?? currentPortTarget
        if let ip { updateDevicePorts(ip: ip); analyzeVulnerabilities(for: ip) }
        
        print("✅ Port scan complete: \(response.count ?? 0) open ports")
        currentPortTarget = nil
        endOperation()
    }
    
    private func handleVulnerability(_ response: BLEResponse) {
        guard let ip = response.ip ?? selectedDevice?.ip,
              let cve = response.cve,
              let severity = response.severity,
              let description = response.description else { return }
        
        let vuln = Vulnerability(
            cve: cve,
            severity: severity,
            description: description
        )
        
        if tempVulnerabilities[ip] == nil {
            tempVulnerabilities[ip] = []
        }
        tempVulnerabilities[ip]?.append(vuln)
        
        // Update device vulnerabilities
        updateDeviceVulnerabilities(ip: ip)
    }
    
    private func handleAnalysisComplete(_ response: BLEResponse) {
        isAnalyzing = false
        analysisProgress = 1.0
        isPortScanning = false
        portScanProgress = 1.0
        
        if let ip = response.ip ?? selectedDevice?.ip {
            updateDeviceVulnerabilities(ip: ip)
        }
        
        print("✅ Analysis complete: \(response.vulns ?? 0) vulnerabilities, max severity: \(response.maxSeverity ?? 0)")
        endOperation()
    }
    
    private func handlePortRaw(_ response: BLEResponse) {
        guard let portNumber = response.port else { return }
        let ip = response.ip ?? currentPortTarget ?? selectedDevice?.ip
        guard let ip else { return }
        
        var combinedBanner = ""
        if let banner = response.banner, !banner.isEmpty { combinedBanner = banner }
        if let version = response.version, !version.isEmpty {
            combinedBanner = combinedBanner.isEmpty ? version : "\(combinedBanner) | \(version)"
        }
        
        let port = OpenPort(
            number: portNumber,
            service: response.service ?? "Unknown",
            banner: combinedBanner.isEmpty ? nil : combinedBanner
        )
        
        storeOpenPort(ip: ip, port: port)
    }
    
    private func handlePortSummary(_ response: BLEResponse) {
        let ip = response.target ?? currentPortTarget ?? selectedDevice?.ip
        guard let ip else { return }
        
        if let entries = response.openPorts {
            var ports: [OpenPort] = []
            for entry in entries {
                let banner = entry.banner ?? entry.version
                let port = OpenPort(
                    number: entry.port,
                    service: entry.service ?? "Unknown",
                    banner: banner
                )
                ports.append(port)
            }
            tempPorts[ip] = dedupePorts(ports)
            updateDevicePorts(ip: ip)
            analyzeVulnerabilities(for: ip)
        }
        
        isPortScanning = false
        portScanProgress = 1.0
        currentPortTarget = nil
        endOperation()
    }
    
    private func updateDevicePorts(ip: String) {
        if let index = networkDevices.firstIndex(where: { $0.ip == ip }),
           let ports = tempPorts[ip] {
            networkDevices[index].ports = ports
        }
        
        // Also update selected device
        if selectedDevice?.ip == ip, let ports = tempPorts[ip] {
            selectedDevice?.ports = ports
        }
    }
    
    private func dedupePorts(_ ports: [OpenPort]) -> [OpenPort] {
        var seen: Set<Int> = []
        var result: [OpenPort] = []
        for port in ports {
            if seen.insert(port.number).inserted {
                result.append(port)
            }
        }
        return result.sorted { $0.number < $1.number }
    }
    
    private func storeOpenPort(ip: String, port: OpenPort) {
        var list = tempPorts[ip] ?? []
        if let idx = list.firstIndex(where: { $0.number == port.number }) {
            list[idx] = port
        } else {
            list.append(port)
        }
        tempPorts[ip] = list
        updateDevicePorts(ip: ip)
        analyzeVulnerabilities(for: ip)
    }
    
    private func analyzeVulnerabilities(for ip: String) {
        guard let ports = tempPorts[ip] else { return }
        var vulns: [Vulnerability] = []
        
        for port in ports {
            switch port.number {
            case 21:
                vulns.append(Vulnerability(cve: "FTP-WeakAuth", severity: 8, description: "FTP service exposed; ensure strong credentials or disable anonymous access."))
            case 22:
                vulns.append(Vulnerability(cve: "SSH-Bruteforce", severity: 5, description: "SSH open; enforce key-based auth and rate limiting."))
            case 23:
                vulns.append(Vulnerability(cve: "Telnet-Exposed", severity: 9, description: "Telnet is insecure; disable or replace with SSH."))
            case 80, 8080:
                vulns.append(Vulnerability(cve: "HTTP-InfoLeak", severity: 4, description: "HTTP service without TLS; check for default creds and outdated software."))
            case 443, 8443:
                vulns.append(Vulnerability(cve: "HTTPS-Misconfig", severity: 4, description: "HTTPS service detected; verify certificates and patch web stack."))
            case 445:
                vulns.append(Vulnerability(cve: "SMB-Exposure", severity: 8, description: "SMB service open; check for SMBv1 disablement and restrict access."))
            case 3389:
                vulns.append(Vulnerability(cve: "RDP-Exposure", severity: 9, description: "RDP exposed; enforce MFA, lock down to VPN, and patch."))
            case 5900:
                vulns.append(Vulnerability(cve: "VNC-Exposure", severity: 7, description: "VNC open; require strong passwords and encryption."))
            default:
                break
            }
        }
        
        // Deduplicate by CVE
        var unique: [String: Vulnerability] = [:]
        for vuln in vulns {
            unique[vuln.cve] = vuln
        }
        tempVulnerabilities[ip] = Array(unique.values)
        updateDeviceVulnerabilities(ip: ip)
    }
    
    private func updateDeviceVulnerabilities(ip: String) {
        if let index = networkDevices.firstIndex(where: { $0.ip == ip }),
           let vulns = tempVulnerabilities[ip] {
            networkDevices[index].vulnerabilities = vulns
        }
        
        // Also update selected device
        if selectedDevice?.ip == ip, let vulns = tempVulnerabilities[ip] {
            selectedDevice?.vulnerabilities = vulns
        }
    }
    
    private func stopAllScans() {
        isWifiScanning = false
        isNetworkScanning = false
        isPortScanning = false
        isAnalyzing = false
        wifiScanProgress = ""
        currentWiFiRequestId = nil
        currentPortTarget = nil
        endOperation()
    }
    
    private func showError(_ message: String) {
        lastError = message
        showingError = true
    }
    
    // MARK: - Timeout Management
    
    private func beginOperation(_ op: OperationKind) {
        activeOperation = op
        refreshInactivityTimer()
    }

    private func refreshInactivityTimer() {
        guard let op = activeOperation else { return }
        lastPacketAt = Date()
        inactivityTimer?.invalidate()
        let interval = inactivityTimeout(for: op)
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleInactivityTimeout(op)
            }
        }
    }

    private func endOperation() {
        activeOperation = nil
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    private func inactivityTimeout(for op: OperationKind) -> TimeInterval {
        switch op {
        case .wifi: return BLEConstants.wifiScanTimeout
        case .network: return BLEConstants.networkScanTimeout
        case .port, .advanced, .analysis: return BLEConstants.portScanTimeout
        }
    }

    private func handleInactivityTimeout(_ op: OperationKind) {
        switch op {
        case .wifi:
            isWifiScanning = false
            currentWiFiRequestId = nil
            showError("Wi-Fi scan stalled (no data)")
        case .network:
            isNetworkScanning = false
            networkDevices = tempDevices
            showError("Network scan stalled (no data)")
        case .port, .advanced:
            isPortScanning = false
            currentPortTarget = nil
            showError("Port scan stalled (no data)")
        case .analysis:
            isAnalyzing = false
            showError("Analysis stalled (no data)")
        }
        endOperation()
    }

    private func startTimeout(_ interval: TimeInterval, handler: @escaping () -> Void) {
        cancelTimeout()
        scanTimeout = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }
    
    private func cancelTimeout() {
        scanTimeout?.invalidate()
        scanTimeout = nil
    }
    
    private func startAckTimeout(_ interval: TimeInterval, handler: @escaping () -> Void) {
        cancelAckTimeout()
        ackTimeout = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }
    
    private func cancelAckTimeout() {
        ackTimeout?.invalidate()
        ackTimeout = nil
    }
    
    private func restartChunkTimeout() {
        chunkTimeout?.invalidate()
        chunkTimeout = Timer.scheduledTimer(withTimeInterval: BLEConstants.wifiScanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isWifiScanning {
                    // Check if we're missing chunks
                    if self.receivedChunks.count < self.expectedTotalChunks {
                        print("⚠️ Chunk timeout - missing chunks")
                        self.showError("Incomplete data received")
                    }
                    self.isWifiScanning = false
                    self.currentWiFiRequestId = nil
                }
            }
        }
    }
    
    private func cancelChunkTimeout() {
        chunkTimeout?.invalidate()
        chunkTimeout = nil
    }
    
    private func cancelAllTimeouts() {
        cancelTimeout()
        cancelAckTimeout()
        cancelChunkTimeout()
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
}

// MARK: - Supporting Types
