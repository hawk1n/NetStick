#include "wifi_scanner.h"

// ============================================================================
// WiFi Scanner - Implementation
// ============================================================================

WiFiScanner wifiScanner;

const char *encryptionTypeToString(wifi_auth_mode_t encType)
{
    switch (encType)
    {
    case WIFI_AUTH_OPEN:
        return "OPEN";
    case WIFI_AUTH_WEP:
        return "WEP";
    case WIFI_AUTH_WPA_PSK:
        return "WPA";
    case WIFI_AUTH_WPA2_PSK:
        return "WPA2";
    case WIFI_AUTH_WPA_WPA2_PSK:
        return "WPA/WPA2";
    case WIFI_AUTH_WPA2_ENTERPRISE:
        return "WPA2-ENT";
    case WIFI_AUTH_WPA3_PSK:
        return "WPA3";
    case WIFI_AUTH_WPA2_WPA3_PSK:
        return "WPA2/WPA3";
    default:
        return "UNKNOWN";
    }
}

void WiFiScanner::init()
{
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    delay(100);
    Serial.println("[WiFi] Initialized in STA mode");
}

int WiFiScanner::scanNetworks()
{
    Serial.println("[WiFi] Starting scan...");

    // Async scan for better responsiveness
    WiFi.scanDelete(); // Clear previous results

    // Synchronous scan
    int n = WiFi.scanNetworks(false, true); // false=sync, true=show hidden

    if (n == WIFI_SCAN_FAILED)
    {
        Serial.println("[WiFi] Scan failed!");
        lastScanCount = 0;
        return -1;
    }

    lastScanCount = n;
    Serial.printf("[WiFi] Found %d networks\n", n);

    return n;
}

WiFiNetworkInfo WiFiScanner::getNetwork(int index)
{
    WiFiNetworkInfo info = {0};

    if (index < 0 || index >= lastScanCount)
    {
        return info;
    }

    String ssid = WiFi.SSID(index);
    strncpy(info.ssid, ssid.c_str(), sizeof(info.ssid) - 1);

    // Format BSSID
    uint8_t *bssid = WiFi.BSSID(index);
    if (bssid)
    {
        snprintf(info.bssid, sizeof(info.bssid), "%02X:%02X:%02X:%02X:%02X:%02X",
                 bssid[0], bssid[1], bssid[2], bssid[3], bssid[4], bssid[5]);
    }

    info.rssi = WiFi.RSSI(index);
    info.channel = WiFi.channel(index);
    info.encType = WiFi.encryptionType(index);
    info.hidden = (ssid.length() == 0);

    return info;
}

String WiFiScanner::getNetworksJson()
{
    JsonDocument doc;
    JsonArray arr = doc.to<JsonArray>();

    for (int i = 0; i < lastScanCount && i < 50; i++)
    { // Limit to 50 networks
        WiFiNetworkInfo net = getNetwork(i);
        JsonObject obj = arr.add<JsonObject>();
        obj["ssid"] = net.ssid;
        obj["bssid"] = net.bssid;
        obj["rssi"] = net.rssi;
        obj["channel"] = net.channel;
        obj["encryption"] = encryptionTypeToString(net.encType);
        obj["hidden"] = net.hidden;

        yield(); // Prevent watchdog timeout
    }

    String output;
    serializeJson(doc, output);
    return output;
}

bool WiFiScanner::connectToNetwork(const char *ssid, const char *password, unsigned long timeoutMs)
{
    Serial.printf("[WiFi] Connecting to: %s\n", ssid);

    // Disconnect if already connected
    if (WiFi.status() == WL_CONNECTED)
    {
        WiFi.disconnect();
        delay(100);
    }

    // Start connection
    if (password && strlen(password) > 0)
    {
        WiFi.begin(ssid, password);
    }
    else
    {
        WiFi.begin(ssid);
    }

    unsigned long startTime = millis();

    while (WiFi.status() != WL_CONNECTED)
    {
        if (millis() - startTime > timeoutMs)
        {
            Serial.println("[WiFi] Connection timeout!");
            WiFi.disconnect();
            return false;
        }

        delay(100);
        yield();

        // Check for connection failure states
        wl_status_t status = WiFi.status();
        if (status == WL_CONNECT_FAILED || status == WL_NO_SSID_AVAIL)
        {
            Serial.printf("[WiFi] Connection failed with status: %d\n", status);
            return false;
        }
    }

    Serial.println("[WiFi] Connected!");
    Serial.printf("[WiFi] IP: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("[WiFi] Gateway: %s\n", WiFi.gatewayIP().toString().c_str());

    return true;
}

void WiFiScanner::disconnect()
{
    WiFi.disconnect();
    Serial.println("[WiFi] Disconnected");
}

String WiFiScanner::getLocalIP() const
{
    return WiFi.localIP().toString();
}

String WiFiScanner::getGatewayIP() const
{
    return WiFi.gatewayIP().toString();
}

String WiFiScanner::getSubnetMask() const
{
    return WiFi.subnetMask().toString();
}

String WiFiScanner::getDNS() const
{
    return WiFi.dnsIP().toString();
}

String WiFiScanner::getSSID() const
{
    return WiFi.SSID();
}

int WiFiScanner::getRSSI() const
{
    return WiFi.RSSI();
}
