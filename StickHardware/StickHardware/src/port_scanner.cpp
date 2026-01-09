#include "port_scanner.h"

// ============================================================================
// Port Scanner - Implementation
// ============================================================================

PortScanner portScanner;

// ============================================================================
// Service Database
// ============================================================================

struct ServiceEntry
{
    uint16_t port;
    const char *name;
};

static const ServiceEntry SERVICE_DATABASE[] PROGMEM = {
    {21, "FTP"},
    {22, "SSH"},
    {23, "Telnet"},
    {53, "DNS"},
    {80, "HTTP"},
    {443, "HTTPS"},
    {445, "SMB"},
    {3306, "MySQL"},
    {3389, "RDP"},
    {5432, "PostgreSQL"},
    {6379, "Redis"},
    {8080, "HTTP Proxy"},
    {0, nullptr} // terminator
};

const char *identifyService(uint16_t port)
{
    for (int i = 0; SERVICE_DATABASE[i].name != nullptr; i++)
    {
        if (SERVICE_DATABASE[i].port == port)
        {
            return SERVICE_DATABASE[i].name;
        }
    }
    return "unknown";
}

const char *identifyServiceByBanner(const char *banner, uint16_t port)
{
    // Trimmed banner heuristics to save flash; fall back to port-based mapping
    (void)banner;
    return identifyService(port);
}

// ============================================================================
// PortScanner Implementation
// ============================================================================

void PortScanner::init()
{
    openPortCount = 0;
    scanProgress = 0;
    scanning = false;
    scanCancelled = false;
}

bool PortScanner::tcpConnect(const char *host, uint16_t port, int timeoutMs)
{
    WiFiClient client;
    client.setTimeout(timeoutMs);

    bool connected = client.connect(host, port, timeoutMs);

    if (connected)
    {
        client.stop();
    }

    return connected;
}

bool PortScanner::grabBanner(WiFiClient &client, char *buffer, size_t bufferSize, int timeoutMs)
{
    if (!client.connected())
    {
        return false;
    }

    memset(buffer, 0, bufferSize);

    unsigned long startTime = millis();
    size_t bytesRead = 0;

    // Wait for data
    while (client.connected() && millis() - startTime < (unsigned long)timeoutMs)
    {
        if (client.available())
        {
            while (client.available() && bytesRead < bufferSize - 1)
            {
                char c = client.read();
                // Only keep printable ASCII
                if (c >= 32 && c < 127)
                {
                    buffer[bytesRead++] = c;
                }
                else if (c == '\n' || c == '\r')
                {
                    buffer[bytesRead++] = ' ';
                }
            }
            break; // Got some data, stop waiting
        }
        delay(10);
        yield();
    }

    // Trim trailing spaces
    while (bytesRead > 0 && buffer[bytesRead - 1] == ' ')
    {
        buffer[--bytesRead] = '\0';
    }

    return bytesRead > 0;
}

bool PortScanner::checkPort(const char *targetIP, uint16_t port, PortResult &result)
{
    result.port = port;
    result.open = false;
    result.valid = true;
    memset(result.service, 0, sizeof(result.service));
    memset(result.banner, 0, sizeof(result.banner));

    WiFiClient client;
    client.setTimeout(PORT_CONNECT_TIMEOUT_MS);

    if (client.connect(targetIP, port, PORT_CONNECT_TIMEOUT_MS))
    {
        result.open = true;

        // Try to grab banner
        // Some services need a probe (HTTP GET, etc.)
        if (port == 80 || port == 8080 || port == 8000 || port == 8008 || port == 3000)
        {
            // Send HTTP request for HTTP ports
            client.print("GET / HTTP/1.0\r\nHost: ");
            client.print(targetIP);
            client.print("\r\n\r\n");
        }

        // Read banner/response
        grabBanner(client, result.banner, sizeof(result.banner), BANNER_READ_TIMEOUT_MS);

        // Identify service
        const char *service = identifyServiceByBanner(result.banner, port);
        strncpy(result.service, service, sizeof(result.service) - 1);

        client.stop();

        Serial.printf("[PortScan] %s:%d OPEN (%s) %s\n",
                      targetIP, port, result.service,
                      result.banner[0] ? result.banner : "");
    }

    return result.open;
}

int PortScanner::scanPorts(const char *targetIP, uint16_t startPort, uint16_t endPort,
                           PortFoundCallback callback,
                           PortProgressCallback progressCb)
{
    Serial.printf("[PortScan] Scanning %s ports %d-%d\n", targetIP, startPort, endPort);

    scanning = true;
    scanCancelled = false;
    openPortCount = 0;
    scanProgress = 0;

    int totalPorts = endPort - startPort + 1;
    int scanned = 0;
    int lastReported = -1;

    for (uint16_t port = startPort; port <= endPort && !scanCancelled; port++)
    {
        PortResult result;

        if (checkPort(targetIP, port, result))
        {
            if (openPortCount < MAX_OPEN_PORTS)
            {
                results[openPortCount++] = result;
            }

            if (callback)
            {
                callback(result);
            }
        }

        scanned++;
        scanProgress = (scanned * 100) / totalPorts;

        if (progressCb && scanProgress != lastReported)
        {
            lastReported = scanProgress;
            progressCb(port, scanProgress, openPortCount);
        }

        yield(); // Prevent watchdog timeout

        // Small delay between connections to avoid overwhelming target
        delay(5);
    }

    scanProgress = 100;
    scanning = false;

    if (progressCb)
    {
        progressCb(endPort, 100, openPortCount);
    }

    Serial.printf("[PortScan] Complete. Found %d open ports.\n", openPortCount);

    return openPortCount;
}

int PortScanner::scanCommonPorts(const char *targetIP, PortFoundCallback callback,
                                 PortProgressCallback progressCb)
{
    Serial.printf("[PortScan] Scanning %s (common ports)\n", targetIP);

    scanning = true;
    scanCancelled = false;
    openPortCount = 0;
    scanProgress = 0;

    int scanned = 0;
    int lastReported = -1;

    for (size_t i = 0; i < COMMON_PORTS_COUNT && !scanCancelled; i++)
    {
        uint16_t port = COMMON_PORTS[i];
        PortResult result;

        if (checkPort(targetIP, port, result))
        {
            if (openPortCount < MAX_OPEN_PORTS)
            {
                results[openPortCount++] = result;
            }

            if (callback)
            {
                callback(result);
            }
        }

        scanned++;
        scanProgress = (scanned * 100) / COMMON_PORTS_COUNT;

        if (progressCb && scanProgress != lastReported)
        {
            lastReported = scanProgress;
            progressCb(port, scanProgress, openPortCount);
        }

        yield();
        delay(5);
    }

    scanProgress = 100;
    scanning = false;

    if (progressCb)
    {
        progressCb(COMMON_PORTS[COMMON_PORTS_COUNT - 1], 100, openPortCount);
    }

    Serial.printf("[PortScan] Complete. Found %d open ports.\n", openPortCount);

    return openPortCount;
}

PortResult PortScanner::getResult(int index) const
{
    if (index >= 0 && index < openPortCount)
    {
        return results[index];
    }
    PortResult empty = {0};
    empty.valid = false;
    return empty;
}
