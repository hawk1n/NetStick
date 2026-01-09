#include "bluetooth_handler.h"
#include <esp_system.h>

// ============================================================================
// Bluetooth Handler - Nordic UART Service Implementation
// ============================================================================
// Protocol Specification:
// - Service UUID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
// - RX Char UUID: 6E400002-... (Write - iPhone sends commands)
// - TX Char UUID: 6E400003-... (Notify - M5Stick sends responses)
// - Format: JSON UTF-8 strings, max ~180 bytes per packet
// ============================================================================

BluetoothHandler bleHandler;

// Forward declarations for BLE callbacks
class NUSServerCallbacks : public BLEServerCallbacks
{
    void onConnect(BLEServer *pServer, esp_ble_gatts_cb_param_t *param) override
    {
        bleHandler.onConnect(param->connect.conn_id);
    }

    void onDisconnect(BLEServer *pServer) override
    {
        bleHandler.onDisconnect();
    }
};

class NUSRxCallbacks : public BLECharacteristicCallbacks
{
    void onWrite(BLECharacteristic *pCharacteristic) override
    {
        std::string value = pCharacteristic->getValue();
        if (value.length() > 0)
        {
            bleHandler.onDataReceived(value.c_str(), value.length());
        }
    }
};

// ============================================================================
// Initialization
// ============================================================================

void BluetoothHandler::init(const char *deviceName)
{
    Serial.println("[BLE] Initializing Nordic UART Service...");

    BLEDevice::init(deviceName);
    server = BLEDevice::createServer();
    server->setCallbacks(new NUSServerCallbacks());

    // Create Nordic UART Service
    nusService = server->createService(NUS_SERVICE_UUID);

    // RX Characteristic - iPhone writes commands here
    rxCharacteristic = nusService->createCharacteristic(
        NUS_RX_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_WRITE_NR
    );
    rxCharacteristic->setCallbacks(new NUSRxCallbacks());

    // TX Characteristic - M5Stick sends responses via notify
    txCharacteristic = nusService->createCharacteristic(
        NUS_TX_CHAR_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    txDescriptor = new BLE2902();
    txCharacteristic->addDescriptor(txDescriptor);

    nusService->start();

    // Configure advertising
    BLEAdvertising *advertising = server->getAdvertising();
    advertising->addServiceUUID(NUS_SERVICE_UUID);
    advertising->setScanResponse(true);
    // iOS-friendly parameters
    advertising->setMinPreferred(0x06);
    advertising->setMinPreferred(0x12);
    advertising->start();

    Serial.println("[BLE] Ready, advertising as: " + String(deviceName));
    Serial.println("[BLE] Service: " NUS_SERVICE_UUID);
}

void BluetoothHandler::update()
{
    // Periodic tasks if needed
}

// ============================================================================
// Connection Callbacks
// ============================================================================

void BluetoothHandler::onConnect(uint16_t connId)
{
    connected = true;
    connectionId = connId;
    cancelRequested = false;
    Serial.printf("[BLE] Client connected (ID: %d)\n", connId);
    
    // Request MTU update just in case (iOS usually initiates, but good to ensure)
    // BLEDevice::setMTU(517); // Set local MTU
}

void BluetoothHandler::onDisconnect()
{
    connected = false;
    cancelRequested = true;  // Cancel any ongoing operation
    Serial.println("[BLE] Client disconnected");
    
    // Restart advertising
    BLEDevice::startAdvertising();
}

// ============================================================================
// Data Reception & Command Parsing
// ============================================================================

void BluetoothHandler::onDataReceived(const char *data, size_t length)
{
    Serial.print("[BLE] RX: ");
    Serial.println(data);

    // Append to buffer (handle fragmented JSON)
    size_t copyLen = min(length, sizeof(rxBuffer) - rxBufferLen - 1);
    memcpy(rxBuffer + rxBufferLen, data, copyLen);
    rxBufferLen += copyLen;
    rxBuffer[rxBufferLen] = '\0';

    // Try to parse complete JSON
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, rxBuffer);
    
    if (error == DeserializationError::Ok)
    {
        // Valid JSON - parse command
        parseCommand(rxBuffer);
        
        // Clear buffer
        rxBufferLen = 0;
        rxBuffer[0] = '\0';
    }
    else if (error == DeserializationError::IncompleteInput)
    {
        // Wait for more data
        Serial.println("[BLE] Waiting for complete JSON...");
    }
    else
    {
        // Invalid JSON - clear and report error
        Serial.print("[BLE] JSON error: ");
        Serial.println(error.c_str());
        sendError("Invalid JSON");
        rxBufferLen = 0;
        rxBuffer[0] = '\0';
    }
    
    // Buffer overflow protection
    if (rxBufferLen > sizeof(rxBuffer) - 100)
    {
        Serial.println("[BLE] Buffer overflow, clearing");
        rxBufferLen = 0;
        rxBuffer[0] = '\0';
    }
}

void BluetoothHandler::parseCommand(const char *json)
{
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, json);

    if (error)
    {
        Serial.print("[BLE] Parse error: ");
        Serial.println(error.c_str());
        sendError("Invalid JSON command");
        return;
    }

    const char *cmd = doc["cmd"];
    if (!cmd)
    {
        sendError("Missing 'cmd' field");
        return;
    }

    // Reset pending command
    memset(&pendingCommand, 0, sizeof(pendingCommand));
    pendingCommand.portStart = DEFAULT_PORT_RANGE_START;
    pendingCommand.portEnd = DEFAULT_PORT_RANGE_END;

    // Parse command type
    if (strcmp(cmd, "wifi_scan") == 0)
    {
        pendingCommand.cmd = BLECommand::WIFI_SCAN;
        commandPending = true;
        sendAck("wifi_scan");
        Serial.println("[BLE] Command: wifi_scan");
    }
    else if (strcmp(cmd, "network_scan") == 0)
    {
        pendingCommand.cmd = BLECommand::NETWORK_SCAN;
        commandPending = true;
        sendAck("network_scan");
        Serial.println("[BLE] Command: network_scan");
    }
    else if (strcmp(cmd, "port_scan") == 0)
    {
        const char *target = doc["target"];
        int start = doc["start"] | DEFAULT_PORT_RANGE_START;
        int end = doc["end"] | DEFAULT_PORT_RANGE_END;
        
        if (!target || strlen(target) == 0)
        {
            sendError("Missing 'target' IP");
            return;
        }
        
        strncpy(pendingCommand.targetIP, target, sizeof(pendingCommand.targetIP) - 1);
        pendingCommand.portStart = (uint16_t)start;
        pendingCommand.portEnd = (uint16_t)end;
        pendingCommand.cmd = BLECommand::PORT_SCAN;
        commandPending = true;
        sendAck("port_scan");
        Serial.printf("[BLE] Command: port_scan %s:%d-%d\n", target, start, end);
    }
    else if (strcmp(cmd, "wifi_connect") == 0)
    {
        const char *ssid = doc["ssid"];
        const char *password = doc["password"];
        
        if (!ssid || strlen(ssid) == 0)
        {
            sendError("Missing 'ssid'");
            return;
        }
        
        strncpy(pendingCommand.ssid, ssid, sizeof(pendingCommand.ssid) - 1);
        if (password)
        {
            strncpy(pendingCommand.password, password, sizeof(pendingCommand.password) - 1);
        }
        pendingCommand.cmd = BLECommand::WIFI_CONNECT;
        commandPending = true;
        sendAck("wifi_connect");
        Serial.printf("[BLE] Command: wifi_connect '%s'\n", ssid);
    }
    else if (strcmp(cmd, "advanced_scan") == 0)
    {
        const char *target = doc["target"];
        bool osDetect = doc["osDetect"] | false;
        bool serviceVersion = doc["serviceVersion"] | true;
        int start = doc["start"] | DEFAULT_PORT_RANGE_START;
        int end = doc["end"] | DEFAULT_PORT_RANGE_END;
        
        if (!target || strlen(target) == 0)
        {
            sendError("Missing 'target' IP");
            return;
        }
        
        strncpy(pendingCommand.targetIP, target, sizeof(pendingCommand.targetIP) - 1);
        pendingCommand.osDetect = osDetect;
        pendingCommand.serviceVersion = serviceVersion;
        pendingCommand.portStart = (uint16_t)start;
        pendingCommand.portEnd = (uint16_t)end;
        pendingCommand.cmd = BLECommand::ADVANCED_SCAN;
        commandPending = true;
        sendAck("advanced_scan");
        Serial.printf("[BLE] Command: advanced_scan %s (OS:%d SV:%d) ports %d-%d\n", target, osDetect, serviceVersion, start, end);
    }
    else if (strcmp(cmd, "analyze") == 0)
    {
        const char *target = doc["target"];
        if (!target || strlen(target) == 0)
        {
            sendError("Missing 'target' IP");
            return;
        }
        strncpy(pendingCommand.targetIP, target, sizeof(pendingCommand.targetIP) - 1);
        pendingCommand.cmd = BLECommand::ANALYZE;
        commandPending = true;
        sendAck("analyze");
        Serial.printf("[BLE] Command: analyze %s\n", target);
    }
    else if (strcmp(cmd, "status") == 0)
    {
        pendingCommand.cmd = BLECommand::STATUS;
        commandPending = true;
        sendAck("status");
        Serial.println("[BLE] Command: status");
    }
    else if (strcmp(cmd, "cancel") == 0)
    {
        cancelRequested = true;
        pendingCommand.cmd = BLECommand::CANCEL;
        commandPending = true;
        Serial.println("[BLE] Command: cancel");
        sendCancelled();
    }
    else
    {
        sendError("Unknown command");
        Serial.printf("[BLE] Unknown command: %s\n", cmd);
    }
}

CommandData BluetoothHandler::getCommand()
{
    commandPending = false;
    return pendingCommand;
}

void BluetoothHandler::clearCommand()
{
    commandPending = false;
    memset(&pendingCommand, 0, sizeof(pendingCommand));
}

// ============================================================================
// Notification Sending
// ============================================================================

bool BluetoothHandler::notificationsEnabled()
{
    if (!txCharacteristic || !txDescriptor)
        return false;
    return txDescriptor->getNotifications();
}

void BluetoothHandler::sendNotification(const char *data)
{
    if (!connected || !txCharacteristic)
    {
        Serial.println("[BLE] Cannot send: not connected");
        return;
    }

    if (!notificationsEnabled())
    {
        Serial.println("[BLE] Cannot send: notifications not enabled");
        return;
    }

    // Get negotiated MTU
    uint16_t mtu = server->getPeerMTU(connectionId);
    if (mtu < 23) mtu = 23;
    
    // Calculate max payload size (MTU - 3 bytes for header)
    size_t chunkSize = mtu - 3;
    size_t len = strlen(data);

    // Fragment if needed
    for (size_t offset = 0; offset < len; offset += chunkSize)
    {
        size_t chunkLen = min(chunkSize, len - offset);
        txCharacteristic->setValue((uint8_t *)(data + offset), chunkLen);
        txCharacteristic->notify();
        delay(30); // Slow down to ~33Hz to prevent iOS buffer overflow
    }

    Serial.print("[BLE] TX (");
    Serial.print(len);
    Serial.print("): ");
    // Print first 100 chars for debugging
    if (len > 100)
    {
        char preview[101];
        strncpy(preview, data, 100);
        preview[100] = '\0';
        Serial.print(preview);
        Serial.println("...");
    }
    else
    {
        Serial.println(data);
    }
}

// ============================================================================
// JSON String Escaping
// ============================================================================

void BluetoothHandler::escapeJsonString(const char *input, char *output, size_t maxLen)
{
    if (!input || !output || maxLen < 1)
        return;
        
    size_t j = 0;
    for (size_t i = 0; input[i] && j < maxLen - 1; i++)
    {
        char c = input[i];
        if (c == '"' || c == '\\')
        {
            if (j < maxLen - 2)
            {
                output[j++] = '\\';
                output[j++] = c;
            }
        }
        else if (c >= 32 && c < 127)
        {
            output[j++] = c;
        }
        else if (c == '\n')
        {
            if (j < maxLen - 2)
            {
                output[j++] = '\\';
                output[j++] = 'n';
            }
        }
        else if (c == '\r')
        {
            if (j < maxLen - 2)
            {
                output[j++] = '\\';
                output[j++] = 'r';
            }
        }
        else if (c == '\t')
        {
            if (j < maxLen - 2)
            {
                output[j++] = '\\';
                output[j++] = 't';
            }
        }
        // Skip other control characters
    }
    output[j] = '\0';
}

// ============================================================================
// Response Methods - New Protocol
// ============================================================================

void BluetoothHandler::sendAck(const char *cmd)
{
    char buf[64];
    snprintf(buf, sizeof(buf), "{\"type\":\"ack\",\"cmd\":\"%s\"}", cmd);
    sendNotification(buf);
}

void BluetoothHandler::sendWifiResults(const WiFiNetworkBLE *networks, int count)
{
    // Build JSON: {"type":"wifi_results","networks":[...]}
    // Note: This may exceed MTU and will be automatically fragmented
    
    JsonDocument doc;
    doc["type"] = "wifi_results";
    JsonArray arr = doc["networks"].to<JsonArray>();
    
    for (int i = 0; i < count; i++)
    {
        JsonObject net = arr.add<JsonObject>();
        net["ssid"] = networks[i].ssid;
        net["bssid"] = networks[i].bssid;
        net["rssi"] = networks[i].rssi;
        net["channel"] = networks[i].channel;
        net["encryption"] = networks[i].encryption;
    }
    
    String output;
    serializeJson(doc, output);
    sendNotification(output.c_str());
}

void BluetoothHandler::sendDevice(const char *ip, const char *mac, const char *vendor)
{
    char escapedVendor[64] = {0};
    escapeJsonString(vendor ? vendor : "Unknown", escapedVendor, sizeof(escapedVendor));
    
    char buf[192];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"device\",\"ip\":\"%s\",\"mac\":\"%s\",\"vendor\":\"%s\"}",
             ip ? ip : "",
             mac ? mac : "",
             escapedVendor);
    sendNotification(buf);
}

void BluetoothHandler::sendNetDone(int count)
{
    char buf[48];
    snprintf(buf, sizeof(buf), "{\"type\":\"net_done\",\"count\":%d}", count);
    sendNotification(buf);
}

void BluetoothHandler::sendPortResult(uint16_t port, const char *service, const char *banner)
{
    char escapedBanner[256] = {0};
    if (banner)
    {
        escapeJsonString(banner, escapedBanner, sizeof(escapedBanner));
    }
    
    char buf[384];
    if (banner && strlen(escapedBanner) > 0)
    {
        snprintf(buf, sizeof(buf),
                 "{\"type\":\"port_result\",\"port\":%d,\"service\":\"%s\",\"banner\":\"%s\"}",
                 port,
                 service ? service : "unknown",
                 escapedBanner);
    }
    else
    {
        snprintf(buf, sizeof(buf),
                 "{\"type\":\"port_result\",\"port\":%d,\"service\":\"%s\"}",
                 port,
                 service ? service : "unknown");
    }
    sendNotification(buf);
}

void BluetoothHandler::sendPortRaw(uint16_t port, const char *targetIp, const char *service, const char *banner, const char *version)
{
    char escapedBanner[256] = {0};
    if (banner)
    {
        escapeJsonString(banner, escapedBanner, sizeof(escapedBanner));
    }
    char escapedVersion[128] = {0};
    if (version)
    {
        escapeJsonString(version, escapedVersion, sizeof(escapedVersion));
    }

    char buf[544];
    if (banner && strlen(escapedBanner) > 0)
    {
        snprintf(buf, sizeof(buf),
                 "{\"type\":\"port_raw\",\"ip\":\"%s\",\"port\":%d,\"protocol\":\"tcp\",\"service\":\"%s\",\"banner\":\"%s\",\"version\":\"%s\"}",
                 targetIp ? targetIp : "",
                 port,
                 service ? service : "unknown",
                 escapedBanner,
                 strlen(escapedVersion) ? escapedVersion : "");
    }
    else
    {
        snprintf(buf, sizeof(buf),
                 "{\"type\":\"port_raw\",\"ip\":\"%s\",\"port\":%d,\"protocol\":\"tcp\",\"service\":\"%s\"}",
                 targetIp ? targetIp : "",
                 port,
                 service ? service : "unknown");
    }
    sendNotification(buf);
}

void BluetoothHandler::sendPortDone(int count)
{
    char buf[48];
    snprintf(buf, sizeof(buf), "{\"type\":\"port_done\",\"count\":%d}", count);
    sendNotification(buf);
}

void BluetoothHandler::sendPortSummary(uint16_t startPort, uint16_t endPort, const char *targetIp, const char *os, const PortScanner &scanner)
{
    JsonDocument doc;
    doc["type"] = "port_summary";
    doc["target"] = targetIp ? targetIp : "";
    doc["start"] = startPort;
    doc["end"] = endPort;
    doc["os"] = os ? os : "unknown";

    JsonArray arr = doc["open_ports"].to<JsonArray>();
    for (int i = 0; i < scanner.getOpenPortCount(); ++i)
    {
        PortResult res = scanner.getResult(i);
        JsonObject obj = arr.add<JsonObject>();
        obj["port"] = res.port;
        obj["protocol"] = "tcp";
        obj["service"] = res.service;
        if (strlen(res.banner) > 0)
        {
            obj["banner"] = res.banner;
        }
        obj["version"] = ""; // no version parsing on device
    }

    String output;
    serializeJson(doc, output);
    sendNotification(output.c_str());
}

void BluetoothHandler::sendProgress(const char *operation, int current, int total)
{
    int percent = (total > 0) ? (current * 100 / total) : 0;

    char buf[144];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"progress\",\"stage\":\"%s\",\"operation\":\"%s\",\"current\":%d,\"total\":%d,\"percent\":%d}",
             operation ? operation : "",
             operation ? operation : "",
             current,
             total,
             percent);
    sendNotification(buf);
}

void BluetoothHandler::sendCancelled()
{
    sendNotification("{\"type\":\"cancelled\"}");
}

void BluetoothHandler::sendError(const char *message)
{
    char escapedMsg[128] = {0};
    escapeJsonString(message ? message : "Unknown error", escapedMsg, sizeof(escapedMsg));
    
    char buf[192];
    snprintf(buf, sizeof(buf), "{\"type\":\"error\",\"message\":\"%s\"}", escapedMsg);
    sendNotification(buf);
}

void BluetoothHandler::sendStatus(int battery, bool charging, bool btConnected, bool wifiConnected, const char *ssid, int rssi, const char *operation, int progress)
{
    char escapedSsid[32] = {0};
    escapeJsonString(ssid ? ssid : "unknown", escapedSsid, sizeof(escapedSsid));

    char buf[192];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"status\",\"battery\":%d,\"charging\":%s,\"bt_connected\":%s,\"wifi_connected\":%s,\"ssid\":\"%s\",\"rssi\":%d,\"operation\":\"%s\",\"progress\":%d}",
             battery,
             charging ? "true" : "false",
             btConnected ? "true" : "false",
             wifiConnected ? "true" : "false",
             escapedSsid,
             rssi,
             operation ? operation : "idle",
             progress);
    sendNotification(buf);
}

void BluetoothHandler::sendRaw(const char *json)
{
    sendNotification(json);
}
