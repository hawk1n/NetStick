#ifndef NETWORK_SCANNER_H
#define NETWORK_SCANNER_H

#include <WiFi.h>
#include <lwip/etharp.h>
#include <lwip/netif.h>
#include "config.h"

// ============================================================================
// Network Scanner - ARP scanning and device discovery
// ============================================================================

struct NetworkDevice
{
    IPAddress ip;
    uint8_t mac[6];
    char macStr[18];
    char vendor[32];
    bool valid;
};

// Callback function type for device discovery (for streaming results)
typedef void (*DeviceFoundCallback)(const NetworkDevice &device);

// Progress callback: percent (0-100) and devices found so far
typedef void (*NetworkProgressCallback)(int percent, int devicesFound);

// OUI (Organizationally Unique Identifier) lookup
// Returns vendor name based on MAC address prefix
const char *lookupVendor(const uint8_t *mac);

class NetworkScanner
{
public:
    void init();

    // Scan local network for devices
    // Returns number of devices found
    // device callback is called for each device found (optional)
    // progress callback is called when percent changes (optional)
    int scanNetwork(DeviceFoundCallback callback = nullptr,
                    NetworkProgressCallback progressCb = nullptr);

    // Get scan results
    int getDeviceCount() const { return deviceCount; }
    NetworkDevice getDevice(int index) const;

    // Get subnet info from current connection
    IPAddress getNetworkAddress() const;
    IPAddress getBroadcastAddress() const;
    int getSubnetSize() const;

    // Progress tracking
    int getScanProgress() const { return scanProgress; }
    bool isScanning() const { return scanning; }

    // Cancel ongoing scan
    void cancelScan() { scanCancelled = true; }

private:
    static const int MAX_DEVICES = MAX_DEVICES_IN_SCAN;
    NetworkDevice devices[MAX_DEVICES];
    int deviceCount = 0;
    int scanProgress = 0;
    bool scanning = false;
    bool scanCancelled = false;

    // Send ARP request and wait for reply
    bool arpProbe(IPAddress ip, uint8_t *mac, int timeoutMs = ARP_TIMEOUT_MS);

    // Format MAC address to string
    static void formatMac(const uint8_t *mac, char *str);
};

extern NetworkScanner networkScanner;

#endif // NETWORK_SCANNER_H
