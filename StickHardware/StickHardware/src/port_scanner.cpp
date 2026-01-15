#include "port_scanner.h"
<<<<<<< HEAD
=======
#include <ctype.h>
#include <Arduino.h>
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)

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
<<<<<<< HEAD
    // Trimmed banner heuristics to save flash; fall back to port-based mapping
    (void)banner;
=======
    if (banner && banner[0] != '\0')
    {
        if (strstr(banner, "SSH") != nullptr)
        {
            return "SSH";
        }
        if (strstr(banner, "HTTP") != nullptr || strstr(banner, "GET") != nullptr || strstr(banner, "POST") != nullptr)
        {
            return "HTTP";
        }
        if ((port == 21 || strstr(banner, "FTP") != nullptr) && strncmp(banner, "220", 3) == 0)
        {
            return "FTP";
        }
        if (port == 25 || strstr(banner, "SMTP") != nullptr)
        {
            return "SMTP";
        }
        if (strstr(banner, "POP3") != nullptr)
        {
            return "POP3";
        }
        if (strstr(banner, "IMAP") != nullptr)
        {
            return "IMAP";
        }
    }

>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
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
<<<<<<< HEAD
=======
    detectOSFlag = false;
    serviceVersionFlag = false;
    osDetected = false;
    strncpy(detectedOS, "unknown", sizeof(detectedOS) - 1);
    detectedOS[sizeof(detectedOS) - 1] = '\0';
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
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
<<<<<<< HEAD
=======
    else
    {
        client.stop(); // ensure socket cleanup
        delay(1);
        yield();
    }
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)

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

<<<<<<< HEAD
=======
void PortScanner::configureScanOptions(bool detectOS, bool serviceVersion)
{
    detectOSFlag = detectOS;
    serviceVersionFlag = serviceVersion;
    osDetected = false;
    strncpy(detectedOS, "unknown", sizeof(detectedOS) - 1);
    detectedOS[sizeof(detectedOS) - 1] = '\0';
}

void PortScanner::ensureOsDetected(const char *targetIP)
{
    if (!detectOSFlag || osDetected)
    {
        return;
    }

    char osBuf[sizeof(detectedOS)] = {0};
    if (detectOS(targetIP, osBuf, sizeof(osBuf)))
    {
        strncpy(detectedOS, osBuf, sizeof(detectedOS) - 1);
    }
    else
    {
        strncpy(detectedOS, "unknown", sizeof(detectedOS) - 1);
    }
    detectedOS[sizeof(detectedOS) - 1] = '\0';
    osDetected = true;
}

bool PortScanner::detectOS(const char *targetIP, char *buffer, size_t bufferSize)
{
    if (!buffer || bufferSize == 0)
    {
        return false;
    }

    String os = "Unknown";
    WiFiClient client;

    // Try HTTP server header first
    if (client.connect(targetIP, 80, PORT_CONNECT_TIMEOUT_MS))
    {
        client.print("HEAD / HTTP/1.0\r\nHost: ");
        client.print(targetIP);
        client.print("\r\n\r\n");

        unsigned long timeout = millis() + BANNER_READ_TIMEOUT_MS;
        while (millis() < timeout && client.connected())
        {
            if (client.available())
            {
                String line = client.readStringUntil('\n');
                line.trim();
                line.toLowerCase();
                if (line.startsWith("server:"))
                {
                    if (line.indexOf("windows") != -1 || line.indexOf("iis") != -1)
                    {
                        os = "Windows";
                    }
                    else if (line.indexOf("linux") != -1 || line.indexOf("ubuntu") != -1 || line.indexOf("debian") != -1)
                    {
                        os = "Linux";
                    }
                    else if (line.indexOf("freebsd") != -1)
                    {
                        os = "FreeBSD";
                    }
                    break;
                }
            }
            delay(10);
            yield();
        }
        client.stop();
    }

    // Fallback to SSH banner
    if (os == "Unknown")
    {
        if (client.connect(targetIP, 22, PORT_CONNECT_TIMEOUT_MS))
        {
            unsigned long timeout = millis() + BANNER_READ_TIMEOUT_MS;
            while (!client.available() && millis() < timeout)
            {
                delay(10);
            }
            if (client.available())
            {
                String banner = client.readStringUntil('\n');
                banner.toLowerCase();
                if (banner.indexOf("openssh") != -1)
                {
                    os = "Linux/Unix";
                }
                else if (banner.indexOf("windows") != -1)
                {
                    os = "Windows";
                }
            }
            client.stop();
        }
    }

    strncpy(buffer, os.c_str(), bufferSize - 1);
    buffer[bufferSize - 1] = '\0';
    return os != "Unknown";
}

bool PortScanner::fetchServiceVersion(const char *targetIP, uint16_t port, const char *service, const char *banner, char *buffer, size_t bufferSize)
{
    if (!buffer || bufferSize == 0)
    {
        return false;
    }

    buffer[0] = '\0';

    if (banner && strstr(banner, "SSH-2.0-") != nullptr)
    {
        const char *verStart = strstr(banner, "SSH-2.0-") + strlen("SSH-2.0-");
        strncpy(buffer, verStart, bufferSize - 1);
        buffer[bufferSize - 1] = '\0';
        return true;
    }

    if (banner && strncmp(banner, "220", 3) == 0 && (port == 21 || port == 25))
    {
        strncpy(buffer, banner + 4, bufferSize - 1);
        buffer[bufferSize - 1] = '\0';
        return true;
    }

    bool isHttp = false;
    if (service)
    {
        if (strncmp(service, "HTTP", 4) == 0 || strncmp(service, "https", 5) == 0 || strncmp(service, "Http", 4) == 0)
        {
            isHttp = true;
        }
    }
    if (!isHttp && (port == 80 || port == 8080 || port == 8000 || port == 8008 || port == 3000))
    {
        isHttp = true;
    }

    if (isHttp)
    {
        WiFiClient client;
        if (client.connect(targetIP, port, PORT_CONNECT_TIMEOUT_MS))
        {
            client.print("HEAD / HTTP/1.0\r\nHost: ");
            client.print(targetIP);
            client.print("\r\n\r\n");

            unsigned long timeout = millis() + BANNER_READ_TIMEOUT_MS;
            while (millis() < timeout && client.connected())
            {
                if (client.available())
                {
                    String line = client.readStringUntil('\n');
                    line.trim();
                    if (line.startsWith("Server: "))
                    {
                        String version = line.substring(8);
                        strncpy(buffer, version.c_str(), bufferSize - 1);
                        buffer[bufferSize - 1] = '\0';
                        client.stop();
                        return true;
                    }
                    if (line.length() == 0)
                    {
                        break;
                    }
                }
                delay(10);
                yield();
            }
            client.stop();
        }
    }

    return buffer[0] != '\0';
}

void PortScanner::determineService(const char *targetIP, uint16_t port, PortResult &result)
{
    const char *service = identifyServiceByBanner(result.banner, port);
    strncpy(result.service, service, sizeof(result.service) - 1);
    result.service[sizeof(result.service) - 1] = '\0';

    if (serviceVersionFlag)
    {
        char version[sizeof(result.version)] = {0};
        if (fetchServiceVersion(targetIP, port, result.service, result.banner, version, sizeof(version)))
        {
            strncpy(result.version, version, sizeof(result.version) - 1);
        }
    }

    if (detectOSFlag)
    {
        ensureOsDetected(targetIP);
        strncpy(result.os, detectedOS, sizeof(result.os) - 1);
        result.os[sizeof(result.os) - 1] = '\0';
    }
}

>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
bool PortScanner::checkPort(const char *targetIP, uint16_t port, PortResult &result)
{
    result.port = port;
    result.open = false;
    result.valid = true;
    memset(result.service, 0, sizeof(result.service));
    memset(result.banner, 0, sizeof(result.banner));
<<<<<<< HEAD
=======
    memset(result.version, 0, sizeof(result.version));
    memset(result.os, 0, sizeof(result.os));
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)

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

<<<<<<< HEAD
        // Identify service
        const char *service = identifyServiceByBanner(result.banner, port);
        strncpy(result.service, service, sizeof(result.service) - 1);
=======
        // Identify service/version/OS
        determineService(targetIP, port, result);
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)

        client.stop();

        Serial.printf("[PortScan] %s:%d OPEN (%s) %s\n",
                      targetIP, port, result.service,
                      result.banner[0] ? result.banner : "");
    }
<<<<<<< HEAD
=======
    else
    {
        client.stop(); // ensure socket cleanup on failures
    }
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)

    return result.open;
}

int PortScanner::scanPorts(const char *targetIP, uint16_t startPort, uint16_t endPort,
                           PortFoundCallback callback,
<<<<<<< HEAD
                           PortProgressCallback progressCb)
{
    Serial.printf("[PortScan] Scanning %s ports %d-%d\n", targetIP, startPort, endPort);

=======
                           PortProgressCallback progressCb,
                           bool detectOS,
                           bool serviceVersion)
{
    Serial.printf("[PortScan] Scanning %s ports %d-%d\n", targetIP, startPort, endPort);

    configureScanOptions(detectOS, serviceVersion);
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
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
<<<<<<< HEAD
                                 PortProgressCallback progressCb)
{
    Serial.printf("[PortScan] Scanning %s (common ports)\n", targetIP);

=======
                                 PortProgressCallback progressCb,
                                 bool detectOS,
                                 bool serviceVersion)
{
    Serial.printf("[PortScan] Scanning %s (common ports)\n", targetIP);

    configureScanOptions(detectOS, serviceVersion);
>>>>>>> f55fe60 (chore: add .gitignore and cleanup)
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
