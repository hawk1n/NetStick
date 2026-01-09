#ifndef WIFI_SCANNER_H
#define WIFI_SCANNER_H

#include <WiFi.h>
#include <ArduinoJson.h>
#include "config.h"

// ============================================================================
// WiFi Scanner - Scan and connect to WiFi networks
// ============================================================================

// Encryption type names
const char *encryptionTypeToString(wifi_auth_mode_t encType);

struct WiFiNetworkInfo
{
    char ssid[33];
    char bssid[18];
    int32_t rssi;
    uint8_t channel;
    wifi_auth_mode_t encType;
    bool hidden;
};

class WiFiScanner
{
public:
    void init();

    // Scan for available networks
    // Returns number of networks found, -1 on error
    int scanNetworks();

    // Get network info by index (after scan)
    WiFiNetworkInfo getNetwork(int index);

    // Get all networks as JSON array string
    String getNetworksJson();

    // Connect to a network
    // Returns true on success
    bool connectToNetwork(const char *ssid, const char *password,
                          unsigned long timeoutMs = WIFI_CONNECT_TIMEOUT_MS);

    // Disconnect from current network
    void disconnect();

    // Connection status
    bool isConnected() const { return WiFi.status() == WL_CONNECTED; }

    // Get connection info
    String getLocalIP() const;
    String getGatewayIP() const;
    String getSubnetMask() const;
    String getDNS() const;
    String getSSID() const;
    int getRSSI() const;

    // Get last scan count
    int getLastScanCount() const { return lastScanCount; }

private:
    int lastScanCount = 0;
};

extern WiFiScanner wifiScanner;

#endif // WIFI_SCANNER_H
