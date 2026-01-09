#include "network_scanner.h"
#include <lwip/ip4_addr.h>
#include <lwip/inet.h>
#include <esp_netif.h>
#include <esp_wifi.h>

// ============================================================================
// Network Scanner - Implementation
// ============================================================================

NetworkScanner networkScanner;

// ============================================================================
// OUI Database (common vendors) - stored in PROGMEM to save RAM
// ============================================================================

struct OUIEntry
{
    uint8_t oui[3];
    const char *vendor;
};

// Common OUI prefixes (add more as needed)
static const OUIEntry OUI_DATABASE[] PROGMEM = {
    {{0xB4, 0xE6, 0x2D}, "Espressif"},
    {{0x24, 0x0A, 0xC4}, "Espressif"},
    {{0x00, 0x17, 0xF2}, "Apple"},
    {{0xAC, 0xBC, 0x32}, "Apple"},
    {{0x00, 0x00, 0x0C}, "Cisco"},
    {{0x00, 0x0C, 0x43}, "TP-Link"},
    {{0x00, 0x00, 0x00}, nullptr} // Terminator
};

#define OUI_DATABASE_SIZE (sizeof(OUI_DATABASE) / sizeof(OUI_DATABASE[0]) - 1)

const char *lookupVendor(const uint8_t *mac)
{
    for (size_t i = 0; i < OUI_DATABASE_SIZE; i++)
    {
        if (memcmp(mac, OUI_DATABASE[i].oui, 3) == 0)
        {
            return OUI_DATABASE[i].vendor;
        }
    }
    return "Unknown";
}

// ============================================================================
// NetworkScanner Implementation
// ============================================================================

void NetworkScanner::init()
{
    deviceCount = 0;
    scanProgress = 0;
    scanning = false;
    scanCancelled = false;
}

void NetworkScanner::formatMac(const uint8_t *mac, char *str)
{
    snprintf(str, 18, "%02X:%02X:%02X:%02X:%02X:%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

IPAddress NetworkScanner::getNetworkAddress() const
{
    IPAddress ip = WiFi.localIP();
    IPAddress mask = WiFi.subnetMask();
    return IPAddress(ip[0] & mask[0], ip[1] & mask[1], ip[2] & mask[2], ip[3] & mask[3]);
}

IPAddress NetworkScanner::getBroadcastAddress() const
{
    IPAddress ip = WiFi.localIP();
    IPAddress mask = WiFi.subnetMask();
    return IPAddress(
        (ip[0] & mask[0]) | (~mask[0] & 0xFF),
        (ip[1] & mask[1]) | (~mask[1] & 0xFF),
        (ip[2] & mask[2]) | (~mask[2] & 0xFF),
        (ip[3] & mask[3]) | (~mask[3] & 0xFF));
}

int NetworkScanner::getSubnetSize() const
{
    IPAddress mask = WiFi.subnetMask();
    int hostBits = 0;
    for (int i = 0; i < 4; i++)
    {
        uint8_t b = ~mask[i];
        while (b)
        {
            hostBits++;
            b >>= 1;
        }
    }
    return (1 << hostBits) - 2; // Minus network and broadcast addresses
}

bool NetworkScanner::arpProbe(IPAddress ip, uint8_t *mac, int timeoutMs)
{
    // Use ESP-IDF low-level ARP functionality
    ip4_addr_t ipaddr;
    IP4_ADDR(&ipaddr, ip[0], ip[1], ip[2], ip[3]);

    // Try to find in ARP cache first
    struct eth_addr *eth_ret;
    const ip4_addr_t *ip_ret;

    // Get network interface
    struct netif *netif = netif_list;
    while (netif != nullptr)
    {
        if (netif_is_up(netif) && !ip4_addr_isany(netif_ip4_addr(netif)))
        {
            break;
        }
        netif = netif->next;
    }

    if (netif == nullptr)
    {
        return false;
    }

    // Send ARP request
    etharp_request(netif, &ipaddr);

    // Wait for response
    unsigned long startTime = millis();
    while (millis() - startTime < (unsigned long)timeoutMs)
    {
        delay(5);
        yield();

        // Check ARP table
        int8_t idx = etharp_find_addr(netif, &ipaddr, &eth_ret, &ip_ret);
        if (idx >= 0 && eth_ret != nullptr)
        {
            memcpy(mac, eth_ret->addr, 6);
            return true;
        }
    }

    return false;
}

int NetworkScanner::scanNetwork(DeviceFoundCallback callback,
                                NetworkProgressCallback progressCb)
{
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println("[NetScan] Not connected to WiFi!");
        return -1;
    }

    Serial.println("[NetScan] Starting network scan...");

    scanning = true;
    scanCancelled = false;
    deviceCount = 0;
    scanProgress = 0;

    IPAddress myIP = WiFi.localIP();
    IPAddress netAddr = getNetworkAddress();
    IPAddress bcastAddr = getBroadcastAddress();
    int subnetSize = getSubnetSize();

    Serial.printf("[NetScan] Local IP: %s\n", myIP.toString().c_str());
    Serial.printf("[NetScan] Network: %s\n", netAddr.toString().c_str());
    Serial.printf("[NetScan] Broadcast: %s\n", bcastAddr.toString().c_str());
    Serial.printf("[NetScan] Subnet size: %d hosts\n", subnetSize);

    int scannedCount = 0;
    int lastReported = -1;

    // Scan all addresses in subnet
    for (int lastOctet = 1; lastOctet < 255 && !scanCancelled; lastOctet++)
    {
        IPAddress targetIP(netAddr[0], netAddr[1], netAddr[2], lastOctet);

        // Skip our own IP
        if (targetIP == myIP)
        {
            scannedCount++;
            continue;
        }

        // Update progress
        scanProgress = (scannedCount * 100) / 254;
        if (progressCb && scanProgress != lastReported)
        {
            lastReported = scanProgress;
            progressCb(scanProgress, deviceCount);
        }

        uint8_t mac[6] = {0};
        bool found = false;

        // Try ARP probe with retries
        for (int retry = 0; retry < ARP_RETRIES && !found; retry++)
        {
            if (arpProbe(targetIP, mac, ARP_TIMEOUT_MS))
            {
                found = true;
            }
        }

        if (found && deviceCount < MAX_DEVICES)
        {
            NetworkDevice &dev = devices[deviceCount];
            dev.valid = true;
            dev.ip = targetIP;
            memcpy(dev.mac, mac, 6);
            formatMac(mac, dev.macStr);

            const char *vendor = lookupVendor(mac);
            strncpy(dev.vendor, vendor, sizeof(dev.vendor) - 1);
            dev.vendor[sizeof(dev.vendor) - 1] = '\0';

            Serial.printf("[NetScan] Found: %s - %s (%s)\n",
                          targetIP.toString().c_str(), dev.macStr, dev.vendor);

            if (callback)
            {
                callback(dev);
            }

            deviceCount++;
        }

        scannedCount++;
        yield(); // Prevent watchdog timeout
    }

    scanProgress = 100;
    scanning = false;
    if (progressCb)
    {
        progressCb(100, deviceCount);
    }

    Serial.printf("[NetScan] Scan complete. Found %d devices.\n", deviceCount);

    return deviceCount;
}

NetworkDevice NetworkScanner::getDevice(int index) const
{
    if (index >= 0 && index < deviceCount)
    {
        return devices[index];
    }

    NetworkDevice empty;
    memset(&empty, 0, sizeof(empty));
    empty.valid = false;
    empty.ip = IPAddress();
    return empty;
}
