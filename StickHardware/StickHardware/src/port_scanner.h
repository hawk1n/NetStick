#ifndef PORT_SCANNER_H
#define PORT_SCANNER_H

#include <WiFi.h>
#include <WiFiClient.h>
#include "config.h"

// ============================================================================
// Port Scanner - TCP port scanning with banner grabbing
// ============================================================================

struct PortResult
{
    uint16_t port;
    bool open;
    char service[16];
    char banner[BANNER_MAX_SIZE];
    bool valid;
};

// Callback for open port found (streaming results)
typedef void (*PortFoundCallback)(const PortResult &result);

// Progress callback: current port being tested, percent (0-100), open count so far
typedef void (*PortProgressCallback)(uint16_t currentPort, int percent, int openCount);

// Service identification based on port
const char *identifyService(uint16_t port);

// Service identification based on banner
const char *identifyServiceByBanner(const char *banner, uint16_t port);

class PortScanner
{
public:
    void init();

    // Scan a range of ports on target IP
    // Returns number of open ports found
    int scanPorts(const char *targetIP, uint16_t startPort, uint16_t endPort,
                  PortFoundCallback callback = nullptr,
                  PortProgressCallback progressCb = nullptr);

    // Scan common ports only (faster)
    int scanCommonPorts(const char *targetIP, PortFoundCallback callback = nullptr,
                        PortProgressCallback progressCb = nullptr);

    // Single port check
    bool checkPort(const char *targetIP, uint16_t port, PortResult &result);

    // Get results
    int getOpenPortCount() const { return openPortCount; }
    PortResult getResult(int index) const;

    // Progress tracking
    int getScanProgress() const { return scanProgress; }
    bool isScanning() const { return scanning; }

    // Cancel scan
    void cancelScan() { scanCancelled = true; }

private:
    static const int MAX_OPEN_PORTS = 100;
    PortResult results[MAX_OPEN_PORTS];
    int openPortCount = 0;
    int scanProgress = 0;
    bool scanning = false;
    bool scanCancelled = false;

    // TCP connect with timeout
    bool tcpConnect(const char *host, uint16_t port, int timeoutMs);

    // Grab banner from open connection
    bool grabBanner(WiFiClient &client, char *buffer, size_t bufferSize, int timeoutMs);
};

extern PortScanner portScanner;

#endif // PORT_SCANNER_H
