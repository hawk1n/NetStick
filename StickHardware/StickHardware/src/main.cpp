// ============================================================================
// M5Stick Plus2 Network Scanner - Main Entry Point
// ============================================================================
// LEGAL USE ONLY: This tool is for authorized network testing only.
// Unauthorized access to networks is illegal.
// ============================================================================

#include <M5Unified.h>
#include "config.h"
#include "display_manager.h"
#include "bluetooth_handler.h"
#include "wifi_scanner.h"
#include "network_scanner.h"
#include "port_scanner.h"
#include "vulnerability_db.h"
#include <mbedtls/base64.h>
#include <time.h>

// ============================================================================
// Global State
// ============================================================================

static unsigned long lastActivityTime = 0;
static bool legalWarningAcknowledged = false;
static int batteryLevel = 100;

// Progress helpers (to avoid capturing lambdas with function pointers)
static char progressSubnet[24] = {0};
static char progressTargetIP[16] = {0};
static uint16_t progressTotalPorts = 0;

// Map command to human-readable label for on-screen echo
const char *commandName(BLECommand cmd)
{
    switch (cmd)
    {
    case BLECommand::WIFI_SCAN:
        return "wifi_scan";
    case BLECommand::NETWORK_SCAN:
        return "network_scan";
    case BLECommand::PORT_SCAN:
        return "port_scan";
    case BLECommand::WIFI_CONNECT:
        return "wifi_connect";
    case BLECommand::CANCEL:
        return "cancel";
    default:
        return "unknown";
    }
}

// Simple ISO8601 timestamp generator (falls back to millis if time not set)
String isoTimestamp()
{
    time_t now = time(nullptr);
    if (now <= 1000)
    {
        char buf[32];
        unsigned long ms = millis();
        snprintf(buf, sizeof(buf), "1970-01-01T00:00:%02luZ", (ms / 1000UL) % 60);
        return String(buf);
    }
    struct tm *tm_info = gmtime(&now);
    char buffer[32];
    strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", tm_info);
    return String(buffer);
}

int channelToFrequency(int channel)
{
    if (channel >= 1 && channel <= 14)
        return 2407 + channel * 5; // 2412 for ch1
    if (channel >= 36 && channel <= 177)
        return 5000 + (channel - 34) * 5; // rough mapping
    return 0;
}

const char *securityStringLower(wifi_auth_mode_t encType)
{
    switch (encType)
    {
    case WIFI_AUTH_OPEN:
        return "open";
    case WIFI_AUTH_WEP:
        return "wep";
    case WIFI_AUTH_WPA_PSK:
        return "wpa";
    case WIFI_AUTH_WPA2_PSK:
        return "wpa2";
    case WIFI_AUTH_WPA_WPA2_PSK:
        return "wpa";
    case WIFI_AUTH_WPA2_ENTERPRISE:
        return "wpa2";
    case WIFI_AUTH_WPA3_PSK:
        return "wpa3";
    case WIFI_AUTH_WPA2_WPA3_PSK:
        return "wpa3";
    default:
        return "unknown";
    }
}

uint32_t simpleCrc32(const uint8_t *data, size_t len)
{
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < len; i++)
    {
        crc ^= data[i];
        for (int j = 0; j < 8; j++)
        {
            uint32_t mask = -(crc & 1);
            crc = (crc >> 1) ^ (0xEDB88320 & mask);
        }
    }
    return ~crc;
}

bool base64Encode(const uint8_t *data, size_t len, String &out)
{
    size_t needed = 0;
    int ret = mbedtls_base64_encode(nullptr, 0, &needed, data, len);
    if (ret != MBEDTLS_ERR_BASE64_BUFFER_TOO_SMALL && ret != 0)
        return false;
    std::unique_ptr<unsigned char[]> buf(new unsigned char[needed + 1]);
    ret = mbedtls_base64_encode(buf.get(), needed, &needed, data, len);
    if (ret != 0)
        return false;
    buf[needed] = '\0';
    out = reinterpret_cast<char *>(buf.get());
    return true;
}

// Total counts for progress calculation
static int progressNetworkTotal = 254;
static int progressPortTotal = 1000;

void onNetworkProgress(int percent, int devicesFound)
{
    displayManager.showNetworkScan(progressSubnet, percent, devicesFound);
    int current = (percent * progressNetworkTotal) / 100;
    bleHandler.sendProgress("network_scan", current, progressNetworkTotal);
}

void onPortProgress(uint16_t currentPort, int percent, int openCount)
{
    displayManager.showPortScan(progressTargetIP, currentPort, progressTotalPorts, openCount);
    int current = (percent * progressPortTotal) / 100;
    bleHandler.sendProgress("port_scan", current, progressPortTotal);
}

// ============================================================================
// Callbacks for streaming results to iPhone
// ============================================================================

void onDeviceFound(const NetworkDevice &device)
{
    // Send device using new protocol format
    bleHandler.sendDevice(
        device.ip.toString().c_str(),
        device.macStr,
        device.vendor);

    // Update display with progress
    displayManager.showNetworkScan(
        networkScanner.getNetworkAddress().toString().c_str(),
        networkScanner.getScanProgress(),
        networkScanner.getDeviceCount());
}

void onPortFound(const PortResult &result)
{
    // Send port result using new protocol format
    bleHandler.sendPortResult(
        result.port,
        result.service,
        result.banner);
}

void onVulnFound(const Vulnerability &vuln)
{
    // Send vulnerability as raw JSON (optional feature)
    char buf[256];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"vulnerability\",\"cve\":\"%s\",\"severity\":%d,\"description\":\"%s\"}",
             vuln.cve, vuln.severity, vuln.description);
    bleHandler.sendRaw(buf);
}

// ============================================================================
// Command Processing - New Protocol
// ============================================================================

void processCommand(const CommandData &cmd)
{
    lastActivityTime = millis();

    // Echo last received command on the device screen
    char cmdLabel[48];
    snprintf(cmdLabel, sizeof(cmdLabel), "Cmd: %s", commandName(cmd.cmd));
    displayManager.setLastCommand(cmdLabel);

    switch (cmd.cmd)
    {
    case BLECommand::WIFI_SCAN:
    {
        Serial.println("[Main] Processing: wifi_scan");

        // Check for cancel
        if (bleHandler.isCancelRequested())
        {
            bleHandler.clearCancelFlag();
            break;
        }

        displayManager.showMessage("WiFi scan...", COLOR_PROGRESS, 2500);
        displayManager.showScanningWifi(0);

        int count = wifiScanner.scanNetworks();

        if (count < 0)
        {
            bleHandler.sendError("WiFi scan failed");
            displayManager.showError("Scan failed");
            break;
        }

        // Build WiFi results array (zero-initialize to avoid stray bytes in JSON)
        WiFiNetworkBLE *networks = new WiFiNetworkBLE[count];
        memset(networks, 0, sizeof(WiFiNetworkBLE) * count);

        for (int i = 0; i < count; i++)
        {
            WiFiNetworkInfo net = wifiScanner.getNetwork(i);
            strncpy(networks[i].ssid, net.ssid, sizeof(networks[i].ssid) - 1);
            networks[i].ssid[sizeof(networks[i].ssid) - 1] = '\0';

            strncpy(networks[i].bssid, net.bssid, sizeof(networks[i].bssid) - 1);
            networks[i].bssid[sizeof(networks[i].bssid) - 1] = '\0';
            networks[i].rssi = net.rssi;
            networks[i].channel = net.channel;

            // Convert encryption type to string
            switch (net.encType)
            {
            case WIFI_AUTH_OPEN:
                strcpy(networks[i].encryption, "OPEN");
                break;
            case WIFI_AUTH_WEP:
                strcpy(networks[i].encryption, "WEP");
                break;
            case WIFI_AUTH_WPA_PSK:
                strcpy(networks[i].encryption, "WPA");
                break;
            case WIFI_AUTH_WPA2_PSK:
                strcpy(networks[i].encryption, "WPA2");
                break;
            case WIFI_AUTH_WPA3_PSK:
            case WIFI_AUTH_WPA2_WPA3_PSK:
                strcpy(networks[i].encryption, "WPA3");
                break;
            default:
                strcpy(networks[i].encryption, "UNKNOWN");
                break;
            }

            displayManager.showScanningWifi(i + 1);
        }

        // Send all results at once
        bleHandler.sendWifiResults(networks, count);
        delete[] networks;

        displayManager.showMessage("WiFi scan done", COLOR_OK, 2000);
        break;
    }

    case BLECommand::WIFI_CONNECT:
    {
        Serial.printf("[Main] Processing: wifi_connect '%s'\n", cmd.ssid);

        displayManager.showMessage("Connecting...", COLOR_PROGRESS, 3000);
        displayManager.showConnecting(cmd.ssid);

        bool connected = wifiScanner.connectToNetwork(cmd.ssid, cmd.password);

        if (connected)
        {
            // Send success response
            char buf[192];
            snprintf(buf, sizeof(buf),
                     "{\"type\":\"wifi_connected\",\"ip\":\"%s\",\"gateway\":\"%s\"}",
                     wifiScanner.getLocalIP().c_str(),
                     wifiScanner.getGatewayIP().c_str());
            bleHandler.sendRaw(buf);

            displayManager.showConnected(
                wifiScanner.getLocalIP().c_str(),
                wifiScanner.getGatewayIP().c_str());
            displayManager.showMessage("Connected", COLOR_OK, 2000);
        }
        else
        {
            bleHandler.sendError("WiFi connection failed");
            displayManager.showError("Connection failed");
        }
        break;
    }

    case BLECommand::NETWORK_SCAN:
    {
        Serial.println("[Main] Processing: network_scan");

        if (!wifiScanner.isConnected())
        {
            bleHandler.sendError("WiFi not connected");
            displayManager.showError("Not connected");
            break;
        }

        displayManager.showMessage("Network scan...", COLOR_PROGRESS, 3000);

        networkScanner.init();
        String subnetStr = networkScanner.getNetworkAddress().toString();
        strncpy(progressSubnet, subnetStr.c_str(), sizeof(progressSubnet) - 1);
        progressSubnet[sizeof(progressSubnet) - 1] = '\0';

        displayManager.showNetworkScan(progressSubnet, 0, 0);

        // Scan network - onDeviceFound will send each device via BLE
        int deviceCount = networkScanner.scanNetwork(onDeviceFound, onNetworkProgress);

        // Send completion event
        bleHandler.sendNetDone(deviceCount);

        displayManager.showNetworkScan(progressSubnet, 100, deviceCount);
        displayManager.showMessage("Network scan done", COLOR_OK, 2000);
        break;
    }

    case BLECommand::PORT_SCAN:
    {
        Serial.printf("[Main] Processing: port_scan %s:%d-%d\n",
                      cmd.targetIP, cmd.portStart, cmd.portEnd);

        if (!wifiScanner.isConnected())
        {
            bleHandler.sendError("WiFi not connected");
            displayManager.showError("Not connected");
            break;
        }

        displayManager.showMessage("Port scan...", COLOR_PROGRESS, 3000);

        strncpy(progressTargetIP, cmd.targetIP, sizeof(progressTargetIP) - 1);
        progressTotalPorts = cmd.portEnd - cmd.portStart + 1;
        progressPortTotal = progressTotalPorts;

        displayManager.showPortScan(cmd.targetIP, 0, progressTotalPorts, 0);

        portScanner.init();

        // Scan ports - callback sends each open port via BLE
        portScanner.scanPorts(cmd.targetIP, cmd.portStart, cmd.portEnd, [](const PortResult &result)
                              { bleHandler.sendPortResult(result.port, result.service, result.banner); }, onPortProgress);

        // Send completion event
        bleHandler.sendPortDone(portScanner.getOpenPortCount());

        displayManager.showPortScan(cmd.targetIP, 100, 100, portScanner.getOpenPortCount());
        displayManager.showMessage("Port scan done", COLOR_OK, 2000);
        break;
    }

    case BLECommand::CANCEL:
    {
        Serial.println("[Main] Processing: cancel");
        bleHandler.clearCancelFlag();
        displayManager.showMessage("Cancelled", COLOR_WARNING, 2000);
        break;
    }

    default:
        break;
    }
}

// ============================================================================
// Setup
// ============================================================================

void setup()
{
    // Initialize M5
    auto cfg = M5.config();
    M5.begin(cfg);

    // Initialize serial for debugging
    Serial.begin(SERIAL_BAUD_RATE);
    Serial.println("\n=================================");
    Serial.println("M5Stick Network Scanner v1.0");
    Serial.println("=================================");
    Serial.println("LEGAL USE ONLY!");
    Serial.println("=================================\n");

    // Initialize display
    displayManager.init();
    displayManager.showLegalWarning();

    // Initialize WiFi in STA mode
    wifiScanner.init();

    // Initialize network scanner
    networkScanner.init();

    // Initialize port scanner
    portScanner.init();

    // Initialize vulnerability database
    vulnDB.init();

    // Initialize BLE
    bleHandler.init(BLE_DEVICE_NAME);

    lastActivityTime = millis();

    Serial.println("[Main] Initialization complete");
}

// ============================================================================
// Main Loop
// ============================================================================

void loop()
{
    M5.update();

    // Check for button press to acknowledge legal warning
    if (!legalWarningAcknowledged)
    {
        if (M5.BtnA.wasPressed() || M5.BtnB.wasPressed())
        {
            legalWarningAcknowledged = true;
            displayManager.showIdle();
            lastActivityTime = millis();
        }
        delay(50);
        return;
    }

    // Process BLE commands
    bleHandler.update();
    if (bleHandler.hasCommand())
    {
        CommandData cmd = bleHandler.getCommand();
        processCommand(cmd);
    }

    // Update display periodically
    displayManager.refresh();

    // Check button for status display
    if (M5.BtnA.wasPressed())
    {
        lastActivityTime = millis();

        // Toggle to status screen
        batteryLevel = M5.Power.getBatteryLevel();
        const char *bleStatus = bleHandler.isConnected() ? "connected" : "disconnected";
        const char *wifiStatus = wifiScanner.isConnected() ? wifiScanner.getSSID().c_str() : "not connected";
        displayManager.showStatus(bleStatus, wifiStatus, batteryLevel);
    }

    // Check for idle timeout (auto power-off after 10 minutes)
    if (millis() - lastActivityTime > IDLE_TIMEOUT_MS)
    {
        Serial.println("[Main] Idle timeout - powering off");
        displayManager.showMessage("Auto power off...", COLOR_WARNING, 2000);
        delay(2000);
        M5.Power.powerOff();
    }

    // Update battery level periodically
    static unsigned long lastBatteryCheck = 0;
    if (millis() - lastBatteryCheck > 30000)
    { // Every 30 seconds
        lastBatteryCheck = millis();
        batteryLevel = M5.Power.getBatteryLevel();

        if (batteryLevel < LOW_BATTERY_THRESHOLD)
        {
            displayManager.showMessage("Low battery!", COLOR_ERROR, 3000);
        }
    }

    delay(10);
}
